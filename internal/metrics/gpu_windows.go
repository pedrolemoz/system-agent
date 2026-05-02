//go:build windows

package metrics

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os/exec"
	"sync"
	"unicode/utf16"
)

var (
	gpuOnce           sync.Once
	cachedGPUName     string
	cachedVRAMTotalMB uint64
)

func collectGPU() *GPU {
	if g := nvidiaGPU(); g != nil {
		return g
	}
	return amdGPU()
}

// amdGPU fetches AMD/Intel GPU info.
// Static data (name, total VRAM) probed once via DXGI and cached.
// Dynamic data (used VRAM, GPU %) read from perf counters each call.
func amdGPU() *GPU {
	gpuOnce.Do(probeStaticGPU)
	if cachedGPUName == "" {
		return nil
	}
	usedMB := dedicatedVRAMUsedMB()
	usagePct := gpuEnginePct()
	freeMB := uint64(0)
	if cachedVRAMTotalMB > usedMB {
		freeMB = cachedVRAMTotalMB - usedMB
	}
	return &GPU{
		Present:  true,
		Name:     cachedGPUName,
		UsagePct: round1(usagePct),
		VRAM:     VRAM{TotalMB: cachedVRAMTotalMB, InUseMB: usedMB, FreeMB: freeMB},
	}
}

// probeStaticGPU uses DXGI (inline C# compiled via Add-Type) to get the true 64-bit
// DedicatedVideoMemory. WMI AdapterRAM and the registry are uint32 — cap at ~4 GB,
// wrong for 8 GB+ cards. Script passed via -EncodedCommand (Base64 UTF-16LE) to
// avoid Windows command-line quoting corruption of embedded double-quotes in C# code.
func probeStaticGPU() {
	script := `
$ErrorActionPreference = 'SilentlyContinue'
if (-not ([System.Management.Automation.PSTypeName]'DXGIProbe').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class DXGIProbe {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct Desc {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string Name;
        public uint Vid, Did, Sub, Rev;
        public UIntPtr DedicatedVRAM, DedicatedSys, SharedSys;
        public long Luid;
    }
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int FnEnum(IntPtr f, uint i, out IntPtr a);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int FnGetDesc(IntPtr a, out Desc d);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate uint FnRelease(IntPtr o);
    [DllImport("dxgi.dll")] static extern int CreateDXGIFactory(ref Guid r, out IntPtr p);
    static List<Desc> Enumerate() {
        var res = new List<Desc>();
        Guid iid = new Guid("7b7166ec-21c7-44ae-b21a-c9ae321ae369");
        IntPtr fac; if (CreateDXGIFactory(ref iid, out fac) < 0 || fac == IntPtr.Zero) return res;
        try {
            IntPtr vt = Marshal.ReadIntPtr(fac);
            var enumFn = Marshal.GetDelegateForFunctionPointer<FnEnum>(Marshal.ReadIntPtr(vt, 7 * IntPtr.Size));
            for (uint i = 0; ; i++) {
                IntPtr adp; if (enumFn(fac, i, out adp) < 0 || adp == IntPtr.Zero) break;
                try {
                    IntPtr avt = Marshal.ReadIntPtr(adp);
                    var fn = Marshal.GetDelegateForFunctionPointer<FnGetDesc>(Marshal.ReadIntPtr(avt, 8 * IntPtr.Size));
                    Desc d; fn(adp, out d); res.Add(d);
                } finally {
                    IntPtr avt2 = Marshal.ReadIntPtr(adp);
                    Marshal.GetDelegateForFunctionPointer<FnRelease>(Marshal.ReadIntPtr(avt2, 2 * IntPtr.Size))(adp);
                }
            }
        } finally {
            IntPtr vt2 = Marshal.ReadIntPtr(fac);
            Marshal.GetDelegateForFunctionPointer<FnRelease>(Marshal.ReadIntPtr(vt2, 2 * IntPtr.Size))(fac);
        }
        return res;
    }
    public static string FirstRealGPU() {
        var skip = new string[]{"Microsoft Basic Render Driver","Virtual","Parsec","Remote","Basic Display","Indirect","Hyper-V"};
        var seen = new HashSet<string>();
        foreach (var a in Enumerate()) {
            long vram = (long)a.DedicatedVRAM;
            if (vram <= 0) continue;
            bool bad = false;
            foreach (var s in skip) { if (a.Name.IndexOf(s, StringComparison.OrdinalIgnoreCase) >= 0) { bad = true; break; } }
            if (bad) continue;
            if (!seen.Add(a.Name)) continue;
            long mb = vram / (1024 * 1024);
            return "{\"Name\":\"" + a.Name.Replace("\\","\\\\").Replace("\"","\\\"") + "\",\"TotalMB\":" + mb + "}";
        }
        return "";
    }
}
"@
}
[DXGIProbe]::FirstRealGPU()
`
	out, err := psRun(script)
	if err != nil || len(out) == 0 {
		return
	}
	// Scan for the JSON line — Add-Type emits CLIXML progress noise on stdout
	// before the actual output (lines starting with "#< CLIXML" or "<Objs ...>").
	var info struct {
		Name    string `json:"Name"`
		TotalMB int64  `json:"TotalMB"`
	}
	for _, line := range bytes.Split(out, []byte("\n")) {
		line = bytes.TrimSpace(line)
		if len(line) > 0 && line[0] == '{' {
			if json.Unmarshal(line, &info) == nil && info.Name != "" {
				break
			}
		}
	}
	if info.Name == "" {
		return
	}
	cachedGPUName = info.Name
	cachedVRAMTotalMB = uint64(info.TotalMB)
}

// dedicatedVRAMUsedMB reads current dedicated VRAM usage via GPU Adapter Memory perf counter.
func dedicatedVRAMUsedMB() uint64 {
	out, err := psRun(`$s=(Get-Counter '\GPU Adapter Memory(*)\Dedicated Usage' -EA SilentlyContinue).CounterSamples|` +
		`Where-Object{$_.CookedValue -gt 0}|Measure-Object CookedValue -Sum;` +
		`if($s.Sum){[long][math]::Round($s.Sum/1MB)}`)
	if err != nil {
		return 0
	}
	s := bytes.TrimSpace(out)
	if len(s) == 0 {
		return 0
	}
	var v int64
	if _, err := fmt.Sscan(string(s), &v); err != nil || v < 0 {
		return 0
	}
	return uint64(v)
}

// gpuEnginePct returns total GPU utilization %.
// Method: group all engine samples by engine index, sum per-process contributions
// per engine (= total load on that engine), then take the max across all engines.
// This matches Task Manager's GPU % and correctly handles multi-engine AMD GPUs.
func gpuEnginePct() float64 {
	script := `
$samples = (Get-Counter '\GPU Engine(*)\Utilization Percentage' -EA SilentlyContinue).CounterSamples |
    Where-Object { $_.CookedValue -gt 0 -and $_.InstanceName -notmatch '_part_\d' }
$eng = @{}
foreach ($s in $samples) {
    if ($s.InstanceName -match 'eng_(\d+)_engtype_') {
        $k = $Matches[1]
        $eng[$k] = ($eng[$k] -as [double]) + $s.CookedValue
    }
}
$max = ($eng.Values | Measure-Object -Maximum).Maximum
if ($max -gt 100) { $max = 100 }
if ($max) { [math]::Round($max, 1) }
`
	out, err := psRun(script)
	if err != nil {
		return 0
	}
	s := bytes.TrimSpace(out)
	if len(s) == 0 {
		return 0
	}
	var v float64
	json.Unmarshal(s, &v)
	return v
}

// psRun executes a PowerShell script via -EncodedCommand (Base64 UTF-16LE).
// This bypasses Windows command-line argument quoting, which corrupts embedded
// double-quotes when scripts are passed via -Command on Windows.
func psRun(script string) ([]byte, error) {
	runes := utf16.Encode([]rune(script))
	buf := make([]byte, len(runes)*2)
	for i, r := range runes {
		buf[i*2] = byte(r)
		buf[i*2+1] = byte(r >> 8)
	}
	enc := base64.StdEncoding.EncodeToString(buf)
	return exec.Command("powershell", "-NoProfile", "-NonInteractive", "-EncodedCommand", enc).Output()
}
