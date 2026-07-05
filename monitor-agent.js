#!/usr/bin/env node

import si from 'systeminformation'
import fetch from 'node-fetch'
import dotenv from 'dotenv'
import { readFileSync } from 'fs'

dotenv.config()

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000'
const API_KEY = process.env.API_KEY
const INTERVAL = parseInt(process.env.INTERVAL || '30000') // 30 seconds default

if (!API_KEY) {
  console.error('Error: API_KEY environment variable is required')
  process.exit(1)
}

if (!BACKEND_URL) {
  console.error('Error: BACKEND_URL environment variable is required')
  process.exit(1)
}

async function getMetrics() {
  try {
    const [cpu, mem, temp] = await Promise.all([
      si.currentLoad(),
      si.mem(),
      si.cpuTemperature()
    ])

    // Jika sensor suhu tidak ada (kebanyakan VPS cloud), estimasi dari CPU load
    let temperature = temp.main || 0
    if (temperature === 0) {
      // Estimasi: 35°C base + (CPU% * 0.4) → range 35-75°C
      temperature = Math.round((35 + (cpu.currentLoad || 0) * 0.4) * 10) / 10
    }

    // Baca uptime dari sistem operasi
    const uptime = Math.floor(require('os').uptime())

    // Baca disk
    const disks = await si.fsSize()

    return {
      cpuUsage: Math.round(cpu.currentLoad * 10) / 10 || 0,
      ramUsed: mem.used,
      ramTotal: mem.total,
      temperature: temperature,
      diskUsed: disks[0]?.used || 0,
      diskTotal: disks[0]?.size || 0,
      uptime: uptime
    }
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
      body: JSON.stringify(metrics)
    })

    if (!response.ok) {
      console.error(`[${new Date().toISOString()}] Report failed: ${response.status}`)
      return false
    }

    console.log(`[${new Date().toISOString()}] Metrics reported successfully`)
    return true
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Error reporting metrics:`, error.message)
    return false
  }
}

async function start() {
  console.log(`Starting monitoring agent...`)
  console.log(`Backend URL: ${BACKEND_URL}`)
  console.log(`Report interval: ${INTERVAL}ms`)

  // Report immediately on start
  await reportMetrics()

  // Then report periodically
  setInterval(reportMetrics, INTERVAL)
}

start()
