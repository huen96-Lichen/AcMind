import log from 'electron-log'
import { createSourceItem } from '../storage'

let mediaRecorder: MediaRecorder | null = null
let audioChunks: Blob[] = []
let isRecording = false

export interface VoiceRecording {
  id: string
  duration: number
  audioData?: string
  transcript?: string
}

export function isRecordingActive(): boolean {
  return isRecording
}

export async function startRecording(): Promise<void> {
  if (isRecording) {
    log.warn('Already recording')
    return
  }

  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    
    mediaRecorder = new MediaRecorder(stream, {
      mimeType: 'audio/webm;codecs=opus'
    })
    
    audioChunks = []

    mediaRecorder.ondataavailable = (event) => {
      if (event.data.size > 0) {
        audioChunks.push(event.data)
      }
    }

    mediaRecorder.start(1000)
    isRecording = true
    
    log.info('Voice recording started')
  } catch (error) {
    log.error('Failed to start recording:', error)
    throw error
  }
}

export async function stopRecording(): Promise<VoiceRecording> {
  return new Promise((resolve, reject) => {
    if (!mediaRecorder || !isRecording) {
      reject(new Error('Not recording'))
      return
    }

    mediaRecorder.onstop = async () => {
      try {
        const audioBlob = new Blob(audioChunks, { type: 'audio/webm' })
        const duration = audioBlob.size / 16000
        
        const reader = new FileReader()
        reader.onloadend = async () => {
          const base64data = reader.result as string
          
          const item = await createSourceItem({
            type: 'audio',
            source: 'voice',
            status: 'pending',
            title: `语音 ${new Date().toLocaleString('zh-CN')}`,
            previewText: '语音录制',
            contentPath: '',
            tags: [],
            assetFileIds: [],
            metadata: {
              audioData: base64data,
              duration,
              recordedAt: Date.now()
            }
          })

          mediaRecorder?.stream.getTracks().forEach(track => track.stop())
          mediaRecorder = null
          isRecording = false

          log.info('Voice recording stopped, saved as:', item.id)

          resolve({
            id: item.id,
            duration,
            audioData: base64data
          })
        }
        
        reader.onerror = () => {
          reject(new Error('Failed to read audio data'))
        }
        
        reader.readAsDataURL(audioBlob)
      } catch (error) {
        reject(error)
      }
    }

    mediaRecorder.stop()
  })
}

export function cancelRecording(): void {
  if (mediaRecorder && isRecording) {
    mediaRecorder.stop()
    mediaRecorder.stream.getTracks().forEach(track => track.stop())
    mediaRecorder = null
    audioChunks = []
    isRecording = false
    log.info('Voice recording cancelled')
  }
}

export async function transcribeAudio(audioData: string): Promise<string> {
  log.info('Audio transcription requested (placeholder)')
  
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve('（这是模拟的语音转文字结果）')
    }, 1000)
  })
}
