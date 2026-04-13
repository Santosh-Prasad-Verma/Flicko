/**
 * Drawing Canvas Component
 *
 * Overlay canvas for drawing on screen shares during voice calls.
 * Uses gesture handler for smooth stroke capture.
 * Supports pen, highlighter, eraser, and shape tools.
 */
import React, { useCallback, useMemo, useRef, useState } from 'react';
import {
  View,
  StyleSheet,
  Pressable,
  Text,
  PanResponder,
  type GestureResponderEvent,
  type PanResponderGestureState,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../hooks/useTheme';

export type DrawingTool = 'pen' | 'highlighter' | 'eraser' | 'shape';

interface Point {
  x: number;
  y: number;
}

interface Stroke {
  id: string;
  tool: DrawingTool;
  color: string;
  width: number;
  opacity: number;
  points: Point[];
}

interface DrawingCanvasProps {
  screenShareId: string;
  onStrokeComplete?: (stroke: Omit<Stroke, 'id'>) => void;
  onClear?: () => void;
  enabled?: boolean;
}

const COLORS = ['#FFFFFF', '#FF4444', '#44FF44', '#4488FF', '#FFFF44', '#FF44FF', '#44FFFF', '#FF8800'];

const TOOL_CONFIG: Record<DrawingTool, { width: number; opacity: number }> = {
  pen: { width: 3, opacity: 1 },
  highlighter: { width: 12, opacity: 0.4 },
  eraser: { width: 20, opacity: 1 },
  shape: { width: 3, opacity: 1 },
};

export function DrawingCanvas({
  screenShareId,
  onStrokeComplete,
  onClear,
  enabled = true,
}: DrawingCanvasProps) {
  const { themeColors } = useTheme();
  const [tool, setTool] = useState<DrawingTool>('pen');
  const [color, setColor] = useState(COLORS[0]);
  const [strokes, setStrokes] = useState<Stroke[]>([]);
  const [currentPoints, setCurrentPoints] = useState<Point[]>([]);
  const [showColorPicker, setShowColorPicker] = useState(false);
  const strokeIdCounter = useRef(0);

  const handleStart = useCallback((_: GestureResponderEvent, gesture: PanResponderGestureState) => {
    if (!enabled) return;
    setCurrentPoints([{ x: gesture.x0, y: gesture.y0 }]);
  }, [enabled]);

  const handleMove = useCallback((_: GestureResponderEvent, gesture: PanResponderGestureState) => {
    if (!enabled) return;
    setCurrentPoints(prev => [...prev, { x: gesture.moveX, y: gesture.moveY }]);
  }, [enabled]);

  const handleEnd = useCallback(() => {
    if (!enabled || currentPoints.length < 2) {
      setCurrentPoints([]);
      return;
    }

    strokeIdCounter.current += 1;
    const newStroke: Stroke = {
      id: `stroke-${strokeIdCounter.current}`,
      tool,
      color: tool === 'eraser' ? 'transparent' : color,
      width: TOOL_CONFIG[tool].width,
      opacity: TOOL_CONFIG[tool].opacity,
      points: currentPoints,
    };

    if (tool === 'eraser') {
      // Remove strokes that intersect with eraser path
      setStrokes(prev => prev.filter(s => !strokeIntersects(s, currentPoints, TOOL_CONFIG.eraser.width)));
    } else {
      setStrokes(prev => [...prev, newStroke]);
      onStrokeComplete?.({
        tool: newStroke.tool,
        color: newStroke.color,
        width: newStroke.width,
        opacity: newStroke.opacity,
        points: newStroke.points,
      });
    }

    setCurrentPoints([]);
  }, [enabled, currentPoints, tool, color, onStrokeComplete]);

  const panResponder = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => enabled,
    onMoveShouldSetPanResponder: () => enabled,
    onPanResponderGrant: handleStart,
    onPanResponderMove: handleMove,
    onPanResponderRelease: handleEnd,
    onPanResponderTerminate: handleEnd,
  }), [enabled, handleStart, handleMove, handleEnd]);

  const handleClear = useCallback(() => {
    setStrokes([]);
    onClear?.();
  }, [onClear]);

  const handleUndo = useCallback(() => {
    setStrokes(prev => prev.slice(0, -1));
  }, []);

  return (
    <View style={styles.container}>
      {/* Drawing surface */}
      <View style={styles.canvas} {...panResponder.panHandlers}>
        {/* Render completed strokes */}
        {strokes.map(stroke => (
          <StrokeView key={stroke.id} stroke={stroke} />
        ))}
        {/* Render current stroke */}
        {currentPoints.length > 1 && (
          <StrokeView
            stroke={{
              id: 'current',
              tool,
              color: tool === 'eraser' ? 'rgba(255,255,255,0.3)' : color,
              width: TOOL_CONFIG[tool].width,
              opacity: TOOL_CONFIG[tool].opacity,
              points: currentPoints,
            }}
          />
        )}
      </View>

      {/* Toolbar */}
      <View style={[styles.toolbar, { backgroundColor: themeColors.bgSecondary + 'E6' }]}>
        {/* Tools */}
        <View style={styles.toolGroup}>
          <ToolButton
            icon="pencil"
            active={tool === 'pen'}
            onPress={() => setTool('pen')}
            color={themeColors.textPrimary}
            activeColor={themeColors.accentPrimary}
          />
          <ToolButton
            icon="color-fill"
            active={tool === 'highlighter'}
            onPress={() => setTool('highlighter')}
            color={themeColors.textPrimary}
            activeColor={themeColors.warning}
          />
          <ToolButton
            icon="cut"
            active={tool === 'eraser'}
            onPress={() => setTool('eraser')}
            color={themeColors.textPrimary}
            activeColor={themeColors.danger}
          />
          <ToolButton
            icon="shapes"
            active={tool === 'shape'}
            onPress={() => setTool('shape')}
            color={themeColors.textPrimary}
            activeColor={themeColors.success}
          />
        </View>

        {/* Separator */}
        <View style={[styles.separator, { backgroundColor: themeColors.border }]} />

        {/* Color picker toggle */}
        <Pressable
          style={[styles.colorToggle, { borderColor: themeColors.border }]}
          onPress={() => setShowColorPicker(v => !v)}
        >
          <View style={[styles.colorDot, { backgroundColor: color }]} />
        </Pressable>

        {/* Separator */}
        <View style={[styles.separator, { backgroundColor: themeColors.border }]} />

        {/* Undo / Clear */}
        <View style={styles.toolGroup}>
          <ToolButton
            icon="arrow-undo"
            active={false}
            onPress={handleUndo}
            color={themeColors.textPrimary}
            activeColor={themeColors.accentPrimary}
            disabled={strokes.length === 0}
          />
          <ToolButton
            icon="trash-outline"
            active={false}
            onPress={handleClear}
            color={themeColors.danger}
            activeColor={themeColors.danger}
            disabled={strokes.length === 0}
          />
        </View>
      </View>

      {/* Color picker popup */}
      {showColorPicker && (
        <View style={[styles.colorPicker, { backgroundColor: themeColors.bgSecondary + 'F0' }]}>
          {COLORS.map(c => (
            <Pressable
              key={c}
              style={[
                styles.colorOption,
                { backgroundColor: c, borderColor: c === color ? themeColors.textPrimary : 'transparent' },
              ]}
              onPress={() => { setColor(c); setShowColorPicker(false); }}
            />
          ))}
        </View>
      )}
    </View>
  );
}

// ── Subcomponents ──

function ToolButton({
  icon,
  active,
  onPress,
  color,
  activeColor,
  disabled,
}: {
  icon: string;
  active: boolean;
  onPress: () => void;
  color: string;
  activeColor: string;
  disabled?: boolean;
}) {
  return (
    <Pressable
      style={[styles.toolButton, active && styles.toolButtonActive]}
      onPress={onPress}
      disabled={disabled}
      hitSlop={4}
    >
      <Ionicons
        name={icon as any}
        size={20}
        color={active ? activeColor : color}
        style={{ opacity: disabled ? 0.3 : 1 }}
      />
    </Pressable>
  );
}

function StrokeView({ stroke }: { stroke: Stroke }) {
  if (stroke.points.length < 2) return null;

  return (
    <>
      {stroke.points.map((point, i) => {
        if (i === 0) return null;
        const prev = stroke.points[i - 1];
        const dx = point.x - prev.x;
        const dy = point.y - prev.y;
        const length = Math.sqrt(dx * dx + dy * dy);
        const angle = Math.atan2(dy, dx) * (180 / Math.PI);

        return (
          <View
            key={`${stroke.id}-${i}`}
            style={[
              styles.strokeSegment,
              {
                left: prev.x,
                top: prev.y - stroke.width / 2,
                width: length,
                height: stroke.width,
                backgroundColor: stroke.color,
                opacity: stroke.opacity,
                transform: [{ rotate: `${angle}deg` }],
                borderRadius: stroke.width / 2,
              },
            ]}
            pointerEvents="none"
          />
        );
      })}
    </>
  );
}

// ── Helpers ──

function strokeIntersects(stroke: Stroke, eraserPoints: Point[], eraserWidth: number): boolean {
  const threshold = eraserWidth / 2 + stroke.width / 2;
  for (const ep of eraserPoints) {
    for (const sp of stroke.points) {
      const dist = Math.sqrt((ep.x - sp.x) ** 2 + (ep.y - sp.y) ** 2);
      if (dist < threshold) return true;
    }
  }
  return false;
}

// ── Styles ──

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFillObject,
  },
  canvas: {
    flex: 1,
  },
  strokeSegment: {
    position: 'absolute',
    transformOrigin: 'left center',
  },
  toolbar: {
    position: 'absolute',
    bottom: 16,
    left: 16,
    right: 16,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 12,
    gap: 4,
  },
  toolGroup: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
  },
  toolButton: {
    width: 36,
    height: 36,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  toolButtonActive: {
    backgroundColor: 'rgba(255,255,255,0.12)',
  },
  separator: {
    width: 1,
    height: 24,
    marginHorizontal: 6,
  },
  colorToggle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 4,
  },
  colorDot: {
    width: 20,
    height: 20,
    borderRadius: 10,
  },
  colorPicker: {
    position: 'absolute',
    bottom: 72,
    left: 16,
    right: 16,
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    padding: 12,
    borderRadius: 12,
    gap: 10,
  },
  colorOption: {
    width: 32,
    height: 32,
    borderRadius: 16,
    borderWidth: 3,
  },
});
