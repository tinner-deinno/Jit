const fs = require('fs');
const path = require('path');
const axios = require('axios');
const EventSource = require('eventsource');

class InnovaBotBridge {
  constructor(config = {}) {
    this.endpoint = config.endpoint || 'http://127.0.0.1:7010/sse';
    this.gui = config.gui || 'http://127.0.0.1:7010/gui';
    this.eventSource = null;
    this.sessionID = null;
  }

  /**
   * Establishes connection to the innova-bot MCP SSE server.
   */
  async connect() {
    return new Promise((resolve, reject) => {
      console.log(`[InnovaBotBridge] Connecting to SSE endpoint: ${this.endpoint}...`);

      try {
        this.eventSource = new EventSource(this.endpoint);

        this.eventSource.onopen = () => {
          console.log('[InnovaBotBridge] Connection opened.');
          resolve(true);
        };

        this.eventSource.onmessage = (event) => {
          const data = JSON.parse(event.data);
          if (data.event === 'endpoint') {
            this.sessionID = data.endpoint;
            console.log(`[InnovaBotBridge] Session established. Endpoint: ${this.sessionID}`);
          }
          // Log all incoming events from the bot
          console.log(`[InnovaBotBridge] Event received: ${JSON.stringify(data)}`);
        };

        this.eventSource.onerror = (err) => {
          console.error('[InnovaBotBridge] SSE Error:', err);
          reject(err);
        };
      } catch (e) {
        reject(e);
      }
    });
  }

  /**
   * Sends a command to innova-bot via the established SSE endpoint.
   */
  async sendCommand(method, params = {}) {
    if (!this.sessionID) {
      throw new Error('InnovaBotBridge not connected. Call connect() first.');
    }

    const url = new URL(this.sessionID);
    console.log(`[InnovaBotBridge] Sending command ${method} to ${url.href}...`);

    try {
      const response = await axios.post(url.href, {
        jsonrpc: '2.0',
        id: Date.now(),
        method: method,
        params: params,
      });
      return response.data;
    } catch (e) {
      console.error(`[InnovaBotBridge] Command ${method} failed:`, e.message);
      throw e;
    }
  }

  /**
   * High-level wrapper to send a task to innova-bot.
   */
  async dispatchTask(taskDescription) {
    return this.sendCommand('execute_task', {
      task: taskDescription,
      priority: 'high',
      source: 'Mother-Orchestrator'
    });
  }

  async disconnect() {
    if (this.eventSource) {
      this.eventSource.close();
      console.log('[InnovaBotBridge] Disconnected.');
    }
  }
}

module.exports = InnovaBotBridge;
