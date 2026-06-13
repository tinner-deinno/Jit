<!-- cc-team deliverable
 group: MANUS (manus-parity scaffolds: tools, agent loop, SSE, workspace stream, artifacts, contract tests, docs)
 member: A2 role=dev model=deepseek/deepseek-v4-flash
 finish_reason: stop | tokens: {"prompt_tokens":211,"completion_tokens":670,"total_tokens":881,"prompt_tokens_details":{"cached_tokens":128,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":295,"image_tokens":0},"cache_creation_input_tokens":0} | 7s
 generated: 2026-06-13T05:44:50.006Z -->
```typescript
import { Router, Request, Response, NextFunction } from 'express';
import { artifactService } from '../../services/artifactService'; // adjust path as needed

const router = Router();

/**
 * GET /api/tasks/:taskId/artifacts
 * Returns a list of artifacts for a given task.
 */
router.get('/tasks/:taskId/artifacts', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { taskId } = req.params;
    const artifacts = await artifactService.listArtifacts(taskId);
    res.json(artifacts);
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/tasks/:taskId/artifacts/:name
 * Downloads a specific artifact as an attachment.
 */
router.get('/tasks/:taskId/artifacts/:name', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { taskId, name } = req.params;
    const artifact = await artifactService.getArtifact(taskId, name);

    if (!artifact) {
      res.status(404).json({ error: 'Artifact not found' });
      return;
    }

    // Assume artifact has properties: buffer (Buffer), mimeType (string), name (string)
    const { buffer, mimeType, name: artifactName } = artifact;

    res.setHeader('Content-Type', mimeType || 'application/octet-stream');
    res.setHeader('Content-Disposition', `attachment; filename="${artifactName}"`);
    res.send(buffer);
  } catch (error) {
    next(error);
  }
});

export { router };
// Mount point: app.use('/api', router);
```
