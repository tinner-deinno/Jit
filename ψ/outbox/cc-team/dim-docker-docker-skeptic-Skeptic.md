<!-- cc-team deliverable
 group: dim-docker (Env & Docker Config Analysis)
 member: docker-skeptic role=Skeptic model=deepseek/deepseek-v4-flash
 finish_reason: stop | tokens: {"prompt_tokens":22,"completion_tokens":1416,"total_tokens":1438,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":328,"image_tokens":0},"cache_creation_input_tokens":0} | 22s
 generated: 2026-06-12T10:28:30.354Z -->
I understand you want to review findings from **docker-hunter** (likely a custom script or tool that scans Docker deployments) and ensure that published ports on containers align correctly with internal DNS names (e.g., service names in a compose file or overlay network). Since you didn’t attach any actual findings, I’ll provide a general methodology. If you share the actual output, I can give more specific guidance.

---

## How to Verify Alignment of Published Ports & Internal DNS

### 1. Understand docker-hunter’s Scope
Typical docker-hunter findings include:
- List of running containers with their mapped ports (e.g., `0.0.0.0:8080->80/tcp`)
- Container names, networks, and IPs
- DNS records (if the tool inspects `/etc/hosts` or internal DNS)
- Potential misconfigurations (exposed ports not matching service type, duplicate ports, etc.)

### 2. Check Published Ports vs. Container’s Expected Services
- For each container, note:
  - **Host port** (e.g., `8080`)
  - **Container port** (e.g., `80`)
  - **Container name** (e.g., `web-app`)
- Ask: does the container actually run a service on that container port?
  - `docker inspect <container>` → `Config.ExposedPorts` or run a command inside.
  - If the container runs an Nginx on 80 but maps 8080:80, that’s correct.
  - If it runs a MySQL on 3306 but publishes 3306:80, **misalignment** – the container port is wrong.

### 3. Verify Internal DNS Resolution
- Inside docker networks, containers are reachable by their **service name** (Compose) or **container name** (default `--net=bridge`).
- docker-hunter might list container names and their IPs on each network.
- Test DNS resolution manually:
  ```bash
  docker exec <any-other-container> getent hosts <target-service-name>
  docker exec <any-other-container> nslookup <target-service-name>
  ```
- **Check alignment**: If a service named `api` is expected to answer on port 3000, but the container has published port `4000:3000`, internal consumers using `api:3000` will work fine (container port is 3000). The **host port** does not affect internal DNS.

### 4. Key Alignment Conditions
| Aspect | Correct              | Misalignment                                  |
|--------|----------------------|-----------------------------------------------|
| **Host port ↔ Container port** | Host port may be arbitrary, but the container port must match the service’s listening port. | Container port differs from the actual listening port. |
| **Container name ↔ Service** | DNS name resolves to the container IP. | DNS name resolves to wrong container (e.g., duplicate names, aliases misconfigured). |
| **Port mapping for inter-container communication** | Not needed – containers use container port directly. | Exposing a host port is irrelevant for internal traffic. |

### 5. Common Issues Found by docker-hunter
- **Port collisions**: Two containers map the same host port.
- **Unused port mappings**: Container publishes a port that no process listens on.
- **DNS name name mismatch**: A service named `db` maps to port 5432 internally, but another container tries to reach `database:5432` – that fails.
- **Network isolation**: Containers on different networks cannot resolve each other’s DNS names.

### 6. Action Plan Based on Findings
- For each finding, check:
  - Is the container actually listening on the mapped container port? (`docker logs`, `ss -tlnp` inside)
  - Are the Docker networks correct? (`docker network inspect`)
  - Are service names in `docker-compose.yml` consistent across services that communicate?
- Correct misalignments by:
  - Updating port mappings (`docker run -p` or compose `ports:`)
  - Renaming containers or using `links`/`aliases` (older) or network aliases (`networks.aliases`)
  - Rebuilding with correct `EXPOSE` and listening ports.

### 7. Example Misalignment (Hypothetical)
**docker-hunter finding:**
```
Container: frontend (ports: 0.0.0.0:3000->3000)
Container: backend (ports: 0.0.0.0:8081->5000)
DNS: frontend tries to reach backend:5000
```
- Here the **container port** is 5000, so `backend:5000` is correct.
- But if `backend` actually listens on 8000 (e.g., Python app default), then it’s misaligned – the container port 5000 doesn’t match the actual listening port. Fix by updating the Dockerfile or run command.

---

**Please paste your docker-hunter output** (or a representative snippet), and I’ll walk through each finding with you. Otherwise, you can follow the steps above to self-verify.
