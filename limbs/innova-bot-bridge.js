const fs = require('fs');
const path = require('path');
const axios = require('axios');
const { EventSource } = require('eventsource');
const EventEmitter = require('events');
const http = require('http');
const https = require('https');

const ConnectionState = {
  DISCONNECTED: 'DISCONNECTED',
  CONNECTING: 'CONNECTING',
  CONNECTED: 'CONNECTED',
  RECONNECTING: 'RECONNECTING',
};

const RETRY_CONFIG = {
  MAX_RETRIES: 3,
  INITIAL_DELAY: 1000, // 1s
  MAX_DELAY: 10000,    // 10s
  TIMEOUT: 30000,      // Increased to 30s to allow for slow bot boot
};

class InnovaBotBridge extends EventEmitter {
  constructor(config = {}) {
    super();
    this.endpoint = config.endpoint || 'http://127.0.0.1:7010/sse';
    this.gui = config.gui || 'http://127.0.0.1:7010/gui';
    this.eventSource = null;
    this.sessionID = null;
    this.state = ConnectionState.DISCONNECTED;
    this.reconnectAttempts = 0;
    this.heartbeatTimer = null;

    this.httpAgent = new http.Agent({
      keepAlive: true,
      maxSockets: 100,
      maxFreeSockets: 10
    });
    this.httpsAgent = new https.Agent({
      keepAlive: true,
      maxSockets: 100,
      maxFreeSockets: 10
    });
  }

  async sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async connect() {
    if (this.state === ConnectionState.CONNECTED) {
      return true;
    }

    this.state = ConnectionState.CONNECTING;
    console.log(`[InnovaBotBridge] Attempting to connect to SSE endpoint: ${this.endpoint}...`);

    return new Promise((resolve, reject) => {
      const connectAttempt = () => {
        try {
          this.eventSource = new EventSource(this.endpoint);

          this.eventSource.onopen = () => {
            console.log('[InnovaBotBridge] SSE Connection opened. Monitoring stream for endpoint...');
          };

          // FIX: Use addEventListener for named events like 'endpoint'
          // This resolves the protocol mismatch where the server sends 'event: endpoint'
          this.eventSource.addEventListener('endpoint', (event) => {
            try {
              const endpointUrl = event.data;
              if (endpointUrl) {
                this.sessionID = endpointUrl;
                this.state = ConnectionState.CONNECTED;
                this.reconnectAttempts = 0;
                console.log(`[InnovaBotBridge] Session established via 'endpoint' event. Endpoint: ${this.sessionID}`);
                this.startHeartbeat();
                this.emit('connected', this.sessionID);
                resolve(true);
              }
            } catch (e) {
              console.error('[InnovaBotBridge] Failed to process endpoint event:', e.message);
            }
          });

          this.eventSource.onmessage = (event) => {
            try {
              // Log raw event for debugging unnamed messages
              console.log(`[InnovaBotBridge] RAW UNNAMED EVENT RECEIVED: ${event.data}`);

              const data = JSON.parse(event.data);
              // Backward compatibility: check if endpoint is passed inside a generic message
              if (data.event === 'endpoint' || data.endpoint) {
                this.sessionID = data.endpoint || data.session_id;
                this.state = ConnectionState.CONNECTED;
                this.reconnectAttempts = 0;
                console.log(`[InnovaBotBridge] Session established via generic message. Endpoint: ${this.sessionID}`);
                this.startHeartbeat();
                this.emit('connected', this.sessionID);
                resolve(true);
              }

              this.emit('bot_event', data);
            } catch (e) {
              // It's okay if generic messages aren't JSON (like heartbeats), but we log severe errors
              if (!(e instanceof SyntaxError)) {
                console.error('[InnovaBotBridge] Error processing message:', e.message);
              }
            }
          };

          this.eventSource.onerror = async (err) => {
            console.error('[InnovaBotBridge] SSE Error occurred:', err);
            this.handleDisconnect();
          };

          setTimeout(() => {
            if (!this.sessionID && this.state !== ConnectionState.CONNECTED) {
              console.error('[InnovaBotBridge] SSE connection timeout: Endpoint not received within 30s');
              this.handleDisconnect();
              reject(new Error('SSE connection timeout: Endpoint not received within 30s'));
            }
          }, RETRY_CONFIG.TIMEOUT);

        } catch (e) {
          console.error('[InnovaBotBridge] Connection exception:', e.message);
          reject(e);
        }
      };

      connectAttempt();
    });
  }

  async handleDisconnect() {
    if (this.state === ConnectionState.RECONNECTING) return;
    this.state = ConnectionState.RECONNECTING;
    this.sessionID = null;
    if (this.eventSource) {
      this.eventSource.close();
      this.eventSource = null;
    }
    this.stopHeartbeat();
    this.reconnectAttempts++;
    const delay = Math.min(RETRY_CONFIG.INITIAL_DELAY * Math.pow(2, this.reconnectAttempts - 1), RETRY_CONFIG.MAX_DELAY);
    console.log(`[InnovaBotBridge] Connection lost. Reconnecting in ${delay}ms (Attempt ${this.reconnectAttempts})...`);
    await this.sleep(delay);
    try {
      await this.connect();
    } catch (e) {
      console.error(`[InnovaBotBridge] Reconnection attempt ${this.reconnectAttempts} failed: ${e.message}`);
      this.handleDisconnect();
    }
  }

  startHeartbeat() {
    this.stopHeartbeat();
    this.heartbeatTimer = setInterval(() => {
      if (this.state !== ConnectionState.CONNECTED) {
        console.log('[InnovaBotBridge] Heartbeat check: Connection not active. Triggering reconnect...');
        this.handleDisconnect();
      }
    }, 30000);
  }

  stopHeartbeat() {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  async sendCommand(method, params = {}, attempt = 1) {
    if (!this.sessionID) {
      if (this.state === ConnectionState.DISCONNECTED || this.state === ConnectionState.RECONNECTING) {
        await this.connect();
      }
      if (!this.sessionID) throw new Error('InnovaBotBridge not connected and could not establish session.');
    }

    // The bot's SSE 'endpoint' event returns a RELATIVE path (e.g.
    // "/messages/?session_id=..."). Resolve it against the SSE endpoint origin
    // so axios receives an absolute URL instead of throwing "Invalid URL".
    const url = new URL(this.sessionID, this.endpoint);

    try {
      const response = await axios.post(url.href, {
        jsonrpc: '2.0',
        id: Date.now(),
        method: method,
        params: params,
      }, {
        timeout: RETRY_CONFIG.TIMEOUT,
        httpAgent: this.httpAgent,
        httpsAgent: this.httpsAgent
      });

      return response.data;
    } catch (e) {
      const isTransient = this.isTransientError(e);
      if (isTransient && attempt < RETRY_CONFIG.MAX_RETRIES) {
        const delay = Math.min(RETRY_CONFIG.INITIAL_DELAY * Math.pow(2, attempt - 1), RETRY_CONFIG.MAX_DELAY);
        await this.sleep(delay);
        return this.sendCommand(method, params, attempt + 1);
      }
      throw e;
    }
  }

  isTransientError(error) {
    if (!error.response) return true;
    const status = error.response.status;
    return [429, 502, 503, 504].includes(status);
  }

  async dispatchTask(taskDescription) {
    return this.sendCommand('execute_task', {
      task: taskDescription,
      priority: 'high',
      source: 'Mother-Orchestrator'
    });
  }

  async disconnect() {
    this.stopHeartbeat();
    if (this.eventSource) {
      this.eventSource.close();
      this.eventSource = null;
    }
    this.state = ConnectionState.DISCONNECTED;
    this.sessionID = null;
    console.log('[InnovaBotBridge] Disconnected.');
  }
}

module.exports = InnovaBotBridge;
