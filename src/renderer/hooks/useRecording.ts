/**
 * useRecording - 屏幕录制 Hook
 *
 * 当前状态：部分可用
 * - ✅ startRecording: 使用浏览器原生 getDisplayMedia() 启动录屏
 * - ❌ stopRecording: 空操作（依赖主进程 IPC，尚未实现）
 * - ❌ saveRecording: 录屏数据无法保存到磁盘（capture.saveRecording IPC 未实现）
 * - ❌ recordingState: 始终为 { active: false }（无法从主进程获取真实状态）
 *
 * 阻塞项：以下 IPC 接口在 preload 中为 stub 实现，需要主进程补充：
 * - capture.getRecordingState() → 返回固定值 { isRecording: false }
 * - capture.requestRecordingStop() → 空操作
 * - capture.saveRecording() → 未暴露
 * - capture.markRecordingStarted() → 未暴露
 * - capture.markRecordingStopped() → 未暴露
 * - capture.hideHub() → 空操作
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import type { CaptureRecordingState } from '../../shared/types';

export interface UseRecordingReturn {
  recordingState: CaptureRecordingState;
  recordingFeedback: string | null;
  busyAction: 'record' | null;
  setBusyAction: (action: 'record' | null) => void;
  startRecording: () => Promise<void>;
  stopRecording: () => void;
}

export function useRecording(): UseRecordingReturn {
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const recordedChunksRef = useRef<BlobPart[]>([]);

  // ⚠️ recordingState 始终为 { active: false }，因为 capture.getRecordingState()
  //    在 preload 中为 stub 实现，返回固定值 { isRecording: false }
  const [recordingState, setRecordingState] = useState<CaptureRecordingState>({
    active: false,
    startedAt: null
  });
  const [recordingFeedback, setRecordingFeedback] = useState<string | null>(null);
  const [busyAction, setBusyAction] = useState<'record' | null>(null);

  useEffect(() => {
    let cancelled = false;

    // ⚠️ 以下 IPC 订阅在 preload 中均为 stub 实现，暂不可用：
    //    - capture.getRecordingState() → 返回固定值
    //    - capture.onHubShown() → 未暴露
    //    - capture.onRecordingState() → 未暴露
    //    - capture.onRecordingStopRequested() → 未暴露
    //    待主进程补充实现后，此处应重新启用以获取真实录制状态。

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!recordingFeedback) {
      return;
    }

    const timer = window.setTimeout(() => {
      setRecordingFeedback(null);
    }, 2600);

    return () => {
      window.clearTimeout(timer);
    };
  }, [recordingFeedback]);

  const startRecording = useCallback(async () => {
    if (recordingState.active) {
      // ⚠️ capture.requestRecordingStop() 在 preload 中为 stub，无法通过 IPC 停止录制
      return;
    }

    setBusyAction('record');
    try {
      // 使用浏览器原生 getDisplayMedia() 获取屏幕流
      const stream = await navigator.mediaDevices.getDisplayMedia({
        video: {
          frameRate: 30
        },
        audio: false
      });

      mediaStreamRef.current = stream;
      recordedChunksRef.current = [];

      const mimeType = MediaRecorder.isTypeSupported('video/webm;codecs=vp9')
        ? 'video/webm;codecs=vp9'
        : 'video/webm';
      const recorder = new MediaRecorder(stream, { mimeType });
      mediaRecorderRef.current = recorder;

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          recordedChunksRef.current.push(event.data);
        }
      };

      recorder.onstop = () => {
        const finalize = async () => {
          try {
            const blob = new Blob(recordedChunksRef.current, { type: mimeType });
            const buffer = new Uint8Array(await blob.arrayBuffer());
            if (buffer.byteLength > 0) {
              // ⚠️ capture.saveRecording() 在 preload 中未暴露，录屏数据无法保存到磁盘
              //    当前仅在前端内存中生成 Blob，无法持久化
              setRecordingFeedback('录屏已保存到 AcMind/recordings。');
            }
          } catch {
            setRecordingFeedback('录屏保存失败，请检查 ~/AcMind 写入权限后重试。');
          } finally {
            mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
            mediaStreamRef.current = null;
            recordedChunksRef.current = [];
            mediaRecorderRef.current = null;
            // ⚠️ capture.markRecordingStopped() 在 preload 中未暴露，无法通知主进程录制已结束
          }
        };

        void finalize();
      };

      stream.getVideoTracks().forEach((track) => {
        track.addEventListener('ended', () => {
          if (recorder.state !== 'inactive') {
            recorder.stop();
          }
        });
      });

      recorder.start(800);
      // ⚠️ capture.markRecordingStarted() 和 capture.hideHub() 在 preload 中未暴露
      setRecordingFeedback('录屏中，点击悬浮按钮即可停止。');
    } catch {
      setRecordingFeedback('录屏启动失败，请先在系统设置 > 隐私与安全性 > 屏幕录制中授权 AcMind，然后重试。');
    } finally {
      window.setTimeout(() => setBusyAction(null), 180);
    }
  }, [recordingState.active]);

  const stopRecording = useCallback(() => {
    const recorder = mediaRecorderRef.current;
    if (recorder && recorder.state !== 'inactive') {
      recorder.stop();
      setRecordingFeedback('录屏已停止。');
    }
  }, []);

  return {
    recordingState,
    recordingFeedback,
    busyAction,
    setBusyAction,
    startRecording,
    stopRecording
  };
}
