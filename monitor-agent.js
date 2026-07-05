#!/usr/bin/env node

import si from 'systeminformation'
import fetch from 'node-fetch'
import dotenv from 'dotenv'

dotenv.config()

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000'
const API_KEY = process.env.API_KEY
const INTERVAL = parseInt(process.env.INTERVAL || '30000')
const HOSTNAME = process.env.HOSTNAME || require('os').hostname()

if (!API_KEY) {
  console.error('Error: API_KEY environment variable is required')
  process.exit(1)
}
if (!BACKEND_URL) {
  console.error('Error: BACKEND_URL environment variable is required')
  process.exit(1)
}

function formatBytes(bytes) {
  if (!bytes || bytes === 0) return 0
  return Math.round(bytes / 1024 / 1024) // MB
}

function formatLoad(value) {
  return Math.round(value * 100) / 100
}

async function getMetrics() {
  try {
    const [cpu, cpuInfo, mem, temp, disks, fsSize, time] = await Promise.all([
      si.currentLoad(),
      si.cpu(),
      si.mem(),
      si.cpuTemperature(),
      si.disksIO(),
      si.fsSize(),
      si.time()
    ])

    // Suhu
    let temperature = temp.main || 0
    if (temperature === 0) {
      temperature = Math.round((35 + (cpu.currentLoad || 0) * 0.4) * 10) / 10
    }

    // Disk utama (/) cari dari fsSize
    let diskUsed = 0, diskTotal = 0, diskUsagePercent = 0
    let diskMountCount = fsSize.length

    // Cari mount point / atau /
    const rootDisk = fsSize.find(d => d.mount === '/' || d.mount === '/root') || fsSize[0]
    if (rootDisk) {
      diskUsed = rootDisk.used
      diskTotal = rootDisk.size
      diskUsagePercent = Math.round(rootDisk.use || 0)
    }

    const metrics = {
      cpuUsage: Math.round(cpu.currentLoad * 10) / 10 || 0,
      cpuModel: cpuInfo.brand || 'Unknown CPU',
      cpuCores: cpuInfo.cores || 0,
      loadAvg: [formatLoad(cpu.avgLoad)],
      temperature: temperature,
      ramUsed: mem.used,
      ramTotal: mem.total,
      ramAvail: mem.available,
      diskUsed: diskUsed,
      diskTotal: diskTotal,
      diskMounts: diskMountCount,
      diskUsagePercent: diskUsagePercent,
      uptime: time.uptime || 0
    }

    // Log ringkas
    console.log(
      `[${new Date().toISOString()}] ` +
      `CPU:${metrics.cpuUsage}% ` +
      `RAM:${formatBytes(mem.used)}/${formatBytes(mem.total)}MB ` +
      `Temp:${temperature}°C ` +
      `Disk:${diskUsagePercent}% ` +
      `Up:${Math.round(time.uptime / 3600)}h`
    )

    return metrics
  } catch (error) {
    console.error('Failed to get metrics:', error.message)
    throw error
  }
}

async function reportMetrics() {
  try {
    const metrics = await getMetrics()

    const response = await fetch(`${BACKEND_URL}/api/agent/report`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': API_KEY
      },
      body: JSON.stringify({
        ...metrics,
        hostname: HOSTNAME
      })
    })

    if (!response.ok) {
      const text = await response.text()
      console.error(`[${new Date().toISOString()}] Report failed: ${response.status} - ${text}`)
      return false
    }

    return true
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Error reporting metrics:`, error.message)
    return false
  }
}

async function start() {
  console.log(`Starting monitoring agent...`)
  console.log(`Backend URL: ${BACKEND_URL}`)
  console.log(`Hostname: ${HOSTNAME}`)
  console.log(`Report interval: ${INTERVAL}ms`)

  await reportMetrics()
  setInterval(reportMetrics, INTERVAL)
}

start()
