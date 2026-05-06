/**
 * AnnotationCanvas — 轻标注组件 (Phase 2B)
 *
 * 在截图上进行轻量标注：
 * - 矩形框
 * - 箭头
 * - 文本标注
 *
 * 使用 Canvas 2D API 实现，不依赖外部库。
 */

import { useState, useRef, useCallback, useEffect } from 'react';
import { Button } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';

type AnnotationTool = 'select' | 'rect' | 'arrow' | 'text';

interface Annotation {
  id: string;
  tool: AnnotationTool;
  // rect/arrow: start and end points
  startX?: number;
  startY?: number;
  endX?: number;
  endY?: number;
  // text: position and content
  x?: number;
  y?: number;
  text?: string;
}

interface AnnotationCanvasProps {
  imageUrl: string;
  onSave?: (annotatedImageDataUrl: string) => void;
  onCancel?: () => void;
}

export function AnnotationCanvas({ imageUrl, onSave, onCancel }: AnnotationCanvasProps): JSX.Element {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [tool, setTool] = useState<AnnotationTool>('select');
  const [annotations, setAnnotations] = useState<Annotation[]>([]);
  const [isDrawing, setIsDrawing] = useState(false);
  const [currentAnnotation, setCurrentAnnotation] = useState<Annotation | null>(null);
  const [textInput, setTextInput] = useState<{ x: number; y: number } | null>(null);
  const [textValue, setTextValue] = useState('');
  const imageRef = useRef<HTMLImageElement | null>(null);
  const [imageLoaded, setImageLoaded] = useState(false);

  // 加载图片
  useEffect(() => {
    const img = new Image();
    img.onload = () => {
      imageRef.current = img;
      setImageLoaded(true);
    };
    img.src = imageUrl;
  }, [imageUrl]);

  // 绘制 canvas
  const drawCanvas = useCallback(() => {
    const canvas = canvasRef.current;
    const ctx = canvas?.getContext('2d');
    const img = imageRef.current;
    if (!canvas || !ctx || !img) return;

    // 设置 canvas 尺寸为图片尺寸
    canvas.width = img.naturalWidth;
    canvas.height = img.naturalHeight;

    // 绘制图片
    ctx.drawImage(img, 0, 0);

    // 绘制标注
    for (const ann of annotations) {
      drawAnnotation(ctx, ann);
    }

    // 绘制当前正在创建的标注
    if (currentAnnotation) {
      drawAnnotation(ctx, currentAnnotation);
    }
  }, [annotations, currentAnnotation]);

  useEffect(() => {
    if (imageLoaded) {
      drawCanvas();
    }
  }, [imageLoaded, drawCanvas]);

  // 绘制单个标注
  const drawAnnotation = (ctx: CanvasRenderingContext2D, ann: Annotation) => {
    ctx.strokeStyle = '#ef4444'; // red
    ctx.fillStyle = '#ef4444';
    ctx.lineWidth = 3;
    ctx.font = '16px sans-serif';

    switch (ann.tool) {
      case 'rect':
        if (ann.startX != null && ann.startY != null && ann.endX != null && ann.endY != null) {
          const x = Math.min(ann.startX, ann.endX);
          const y = Math.min(ann.startY, ann.endY);
          const w = Math.abs(ann.endX - ann.startX);
          const h = Math.abs(ann.endY - ann.startY);
          ctx.strokeRect(x, y, w, h);
        }
        break;

      case 'arrow':
        if (ann.startX != null && ann.startY != null && ann.endX != null && ann.endY != null) {
          // 画线
          ctx.beginPath();
          ctx.moveTo(ann.startX, ann.startY);
          ctx.lineTo(ann.endX, ann.endY);
          ctx.stroke();

          // 画箭头
          const angle = Math.atan2(ann.endY - ann.startY, ann.endX - ann.startX);
          const headLen = 15;
          ctx.beginPath();
          ctx.moveTo(ann.endX, ann.endY);
          ctx.lineTo(
            ann.endX - headLen * Math.cos(angle - Math.PI / 6),
            ann.endY - headLen * Math.sin(angle - Math.PI / 6),
          );
          ctx.moveTo(ann.endX, ann.endY);
          ctx.lineTo(
            ann.endX - headLen * Math.cos(angle + Math.PI / 6),
            ann.endY - headLen * Math.sin(angle + Math.PI / 6),
          );
          ctx.stroke();
        }
        break;

      case 'text':
        if (ann.x != null && ann.y != null && ann.text) {
          // 背景
          const metrics = ctx.measureText(ann.text);
          const padding = 4;
          ctx.fillStyle = 'rgba(239, 68, 68, 0.8)';
          ctx.fillRect(
            ann.x - padding,
            ann.y - 16 - padding,
            metrics.width + padding * 2,
            20 + padding * 2,
          );
          // 文字
          ctx.fillStyle = '#ffffff';
          ctx.fillText(ann.text, ann.x, ann.y);
        }
        break;
    }
  };

  // 鼠标事件
  const getCanvasCoords = (e: React.MouseEvent<HTMLCanvasElement>): { x: number; y: number } => {
    const canvas = canvasRef.current!;
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width;
    const scaleY = canvas.height / rect.height;
    return {
      x: (e.clientX - rect.left) * scaleX,
      y: (e.clientY - rect.top) * scaleY,
    };
  };

  const handleMouseDown = (e: React.MouseEvent<HTMLCanvasElement>) => {
    if (tool === 'select') return;

    const { x, y } = getCanvasCoords(e);

    if (tool === 'text') {
      setTextInput({ x, y });
      setTextValue('');
      return;
    }

    setIsDrawing(true);
    setCurrentAnnotation({
      id: `ann-${Date.now()}`,
      tool,
      startX: x,
      startY: y,
      endX: x,
      endY: y,
    });
  };

  const handleMouseMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
    if (!isDrawing || !currentAnnotation) return;

    const { x, y } = getCanvasCoords(e);
    setCurrentAnnotation({
      ...currentAnnotation,
      endX: x,
      endY: y,
    });
  };

  const handleMouseUp = () => {
    if (!isDrawing || !currentAnnotation) return;
    setIsDrawing(false);

    // 只有有意义的标注才保存
    if (
      currentAnnotation.tool === 'rect' || currentAnnotation.tool === 'arrow'
    ) {
      const dx = Math.abs((currentAnnotation.endX ?? 0) - (currentAnnotation.startX ?? 0));
      const dy = Math.abs((currentAnnotation.endY ?? 0) - (currentAnnotation.startY ?? 0));
      if (dx > 5 || dy > 5) {
        setAnnotations((prev) => [...prev, currentAnnotation]);
      }
    }

    setCurrentAnnotation(null);
  };

  const handleTextSubmit = () => {
    if (textInput && textValue.trim()) {
      setAnnotations((prev) => [
        ...prev,
        {
          id: `ann-${Date.now()}`,
          tool: 'text',
          x: textInput.x,
          y: textInput.y,
          text: textValue.trim(),
        },
      ]);
    }
    setTextInput(null);
    setTextValue('');
  };

  const handleUndo = () => {
    setAnnotations((prev) => prev.slice(0, -1));
  };

  const handleSave = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const dataUrl = canvas.toDataURL('image/png');
    onSave?.(dataUrl);
  };

  return (
    <div className="flex flex-col gap-3">
      {/* 工具栏 */}
      <div className="flex items-center gap-2 rounded-[8px] bg-[color:var(--pm-surface)] p-2 shadow-sm">
        <Button
          variant={tool === 'select' ? 'primary' : 'ghost'}
          size="sm"
          onClick={() => setTool('select')}
        >
          选择
        </Button>
        <Button
          variant={tool === 'rect' ? 'primary' : 'ghost'}
          size="sm"
          onClick={() => setTool('rect')}
        >
          矩形
        </Button>
        <Button
          variant={tool === 'arrow' ? 'primary' : 'ghost'}
          size="sm"
          onClick={() => setTool('arrow')}
        >
          箭头
        </Button>
        <Button
          variant={tool === 'text' ? 'primary' : 'ghost'}
          size="sm"
          leadingIcon={<AcMindIcon name="text" size={14} />}
          onClick={() => setTool('text')}
        >
          文字
        </Button>

        <div className="mx-2 h-4 w-px bg-[color:var(--pm-border-subtle)]" />

        <Button
          variant="ghost"
          size="sm"
          leadingIcon={<AcMindIcon name="act-delete" size={14} />}
          onClick={handleUndo}
          disabled={annotations.length === 0}
        >
          撤销
        </Button>

        <div className="flex-1" />

        <Button variant="ghost" size="sm" onClick={onCancel}>
          取消
        </Button>
        <Button variant="primary" size="sm" onClick={handleSave}>
          保存
        </Button>
      </div>

      {/* Canvas */}
      <div className="relative overflow-hidden rounded-[8px] bg-[color:var(--pm-surface-muted)]">
        <canvas
          ref={canvasRef}
          className="max-h-[70vh] w-full cursor-crosshair object-contain"
          onMouseDown={handleMouseDown}
          onMouseMove={handleMouseMove}
          onMouseUp={handleMouseUp}
          onMouseLeave={handleMouseUp}
        />

        {/* 文字输入浮层 */}
        {textInput && (
          <div
            className="absolute"
            style={{ left: textInput.x, top: textInput.y }}
          >
            <input
              autoFocus
              className="rounded border border-red-500 bg-white/90 px-2 py-1 text-sm text-black shadow-sm outline-none"
              placeholder="输入标注文字"
              value={textValue}
              onChange={(e) => setTextValue(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') handleTextSubmit();
                if (e.key === 'Escape') {
                  setTextInput(null);
                  setTextValue('');
                }
              }}
              onBlur={handleTextSubmit}
            />
          </div>
        )}
      </div>
    </div>
  );
}
