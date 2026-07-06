#!/usr/bin/env node

import si from 'systeminformation'
import fetch from 'node-fetch'
import dotenv from 'dotenv'
import os from 'os'
import { readFileSync } from 'fs'

dotenv.config()

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000'
const API_KEY = process.env.API_KEY
const INTERVAL = parseInt(process.env.INTERVAL || '30000')
const HOSTNAME = os.hostname()

if (!API_KEY) { console.error('Error: API_KEY required'); process.exit(1) }
if (!BACKEND_URL) { console.error('Error: BACKEND_URL required'); process.exit(1) }

// ─── CPU Info Fallback ─────────────────────────────────────────────────────
function getCpuInfoSync() {
  let model = '', speed = 0, cores = os.cpus().length

  try {
    const info = readFileSync('/proc/cpuinfo', 'utf-8')
    const lines = info.split('\n')
    for (const line of lines) {
      if (line.startsWith('model name') && !model) {
        model = line.split(':').slice(1).join(':').trim()
      }
      if (line.startsWith('cpu MHz') && !speed) {
        speed = Math.round(parseFloat(line.split(':').slice(1).join(':').trim()))
      }
    }
  } catch {}

  return { model: model || os.cpus()[0]?.model || 'Unknown CPU', speed: speed || os.cpus()[0]?.speed || 0, cores }
}

function fmtB(b) {
  if (!b) return '0 MB'
  const mb = b / 1024 / 1024
  return mb > 1024 ? (mb / 1024).toFixed(1) + ' GB' : Math.round(mb) + ' MB'
}

async function getMetrics() {
  try {
    const [cpu, mem, temp, fsSize] = await Promise.all([
      si.currentLoad(),
      si.mem(),
      si.cpuTemperature(),
      si.fsSize()
    ])

    const cpuInfo = getCpuInfoSync()

    // Suhu
    let temperature = temp.main || 0
    if (temperature === 0) {
      temperature = Math.round((35 + (cpu.currentLoad || 0) * 0.4) * 10) / 10
    }

    // RAM
    const ramUsed = mem.used || 0
    const ramTotal = mem.total || 1
    const ramAvail = mem.available || 0
    const ramPct = Math.round((ramUsed / ramTotal) * 1000) / 10

    // Disk
    const rootDisk = fsSize.find(d => d.mount === '/' || d.mount === '/root') || fsSize[0]
    const diskPct = rootDisk ? Math.round((rootDisk.use || 0) * 10) / 10 : 0

    const metrics = {
      cpuUsage: Math.round(cpu.currentLoad * 10) / 10 || 0,
      cpuModel: cpuInfo.model,
      cpuCores: cpuInfo.cores,
      cpuSpeed: cpuInfo.speed,
      loadAvg: [Math.round((cpu.avgLoad || 0) * 100) / 100, 0, 0],
      temperature,
      ramUsed,
      ramTotal,
      ramAvail,
      ramPercent: ramPct,
      diskUsed: rootDisk?.used || 0,
      diskTotal: rootDisk?.size || 0,
      diskMounts: fsSize.length,
      diskUsagePercent: diskPct,
      uptime: Math.floor(os.uptime())
    }

    console.log(
      `[${new Date().toISOString()}] ` +
      `CPU:${metrics.cpuUsage}%(${cpuInfo.model.split(' ').slice(0,3).join(' ')}) ` +
      `RAM:${fmtB(ramUsed)}/${fmtB(ramTotal)}(${ramPct}%) ` +
      `Temp:${temperature}°C ` +
      `Disk:${diskPct}% ` +
      `Up:${Math.round(metrics.uptime / 3600)}h`
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
      headers: { 'Content-Type': 'application/json', 'x-api-key': API_KEY },
      body: JSON.stringify({ ...metrics, hostname: HOSTNAME })
    })
    if (!response.ok) {
      const t = await response.text()
      console.error(`Report failed: ${response.status} - ${t}`)
    }
  } catch (error) {
    console.error(`Error: ${error.message}`)
  }
}

async function start() {
  console.log(`Starting monitoring agent...`)
  console.log(`Backend: ${BACKEND_URL}`)
  console.log(`Hostname: ${HOSTNAME}`)
  console.log(`Interval: ${INTERVAL}ms`)
  await reportMetrics()
  setInterval(reportMetrics, INTERVAL)
}

start()
