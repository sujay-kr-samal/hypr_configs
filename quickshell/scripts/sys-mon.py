#!/usr/bin/env python3
import time
import json
import subprocess

def get_cpu_times():
    try:
        with open('/proc/stat', 'r') as f:
            for line in f:
                if line.startswith('cpu '):
                    parts = list(map(int, line.split()[1:]))
                    idle = parts[3] + parts[4] # idle + iowait
                    total = sum(parts)
                    return idle, total
    except Exception:
        pass
    return 0, 0

def get_mem_details():
    try:
        mem = {}
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 2:
                    key = parts[0].rstrip(':')
                    val = int(parts[1])
                    mem[key] = val
        total = mem.get('MemTotal', 1)
        free = mem.get('MemFree', 0)
        buffers = mem.get('Buffers', 0)
        cached = mem.get('Cached', 0)
        available = mem.get('MemAvailable', free + buffers + cached)
        used = total - available
        
        # Convert to GB (1024*1024 KB = 1 GB)
        total_gb = total / (1024.0 * 1024.0)
        used_gb = used / (1024.0 * 1024.0)
        util = max(0.0, min(1.0, used / total))
        return util, used_gb, total_gb
    except Exception:
        return 0.0, 0.0, 0.0

def get_gpu_details():
    gpu_util = 0.0
    vram_util = 0.0
    vram_used_gb = 0.0
    vram_total_gb = 0.0
    try:
        res = subprocess.run(
            ['nvidia-smi', '--query-gpu=utilization.gpu,memory.used,memory.total', '--format=csv,noheader,nounits'],
            capture_output=True, text=True, check=True
        )
        parts = res.stdout.strip().split(',')
        if len(parts) >= 3:
            gpu_util = float(parts[0].strip()) / 100.0
            vram_used = float(parts[1].strip()) # in MiB
            vram_total = float(parts[2].strip()) # in MiB
            vram_util = vram_used / vram_total if vram_total > 0 else 0.0
            vram_used_gb = vram_used / 1024.0
            vram_total_gb = vram_total / 1024.0
    except Exception:
        pass
    return gpu_util, vram_util, vram_used_gb, vram_total_gb

def main():
    prev_idle, prev_total = get_cpu_times()
    while True:
        time.sleep(2.0)
        idle, total = get_cpu_times()
        idle_delta = idle - prev_idle
        total_delta = total - prev_total
        cpu_util = 0.0
        if total_delta > 0:
            cpu_util = 1.0 - (idle_delta / total_delta)
        prev_idle, prev_total = idle, total

        mem_util, mem_used_gb, mem_total_gb = get_mem_details()
        gpu_util, vram_util, vram_used_gb, vram_total_gb = get_gpu_details()

        data = {
            'cpu': round(max(0.0, min(1.0, cpu_util)), 4),
            'mem': round(mem_util, 4),
            'mem_used_gb': round(mem_used_gb, 2),
            'mem_total_gb': round(mem_total_gb, 2),
            'gpu': round(max(0.0, min(1.0, gpu_util)), 4),
            'vram': round(max(0.0, min(1.0, vram_util)), 4),
            'vram_used_gb': round(vram_used_gb, 2),
            'vram_total_gb': round(vram_total_gb, 2)
        }
        print(json.dumps(data), flush=True)

if __name__ == '__main__':
    main()
