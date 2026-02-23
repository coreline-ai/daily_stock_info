interface SparklineProps {
  points: number[];
  width?: number;
  height?: number;
}

export default function Sparkline({ points, width = 80, height = 24 }: SparklineProps) {
  if (!points || points.length === 0) {
    return <div className="w-[80px] h-[24px] bg-[#1c2430] rounded border border-[#2d333b]" />;
  }

  const step = points.length > 1 ? width / (points.length - 1) : width;
  const coords = points
    .map((point, idx) => {
      const x = idx * step;
      const y = height - (Math.max(0, Math.min(100, point)) / 100) * height;
      return `${x.toFixed(2)},${y.toFixed(2)}`;
    })
    .join(" ");

  const trend = points[points.length - 1] - points[0];
  const color = trend >= 0 ? "#22c55e" : "#ef4444";

  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} className="rounded bg-[#0f1520] border border-[#2d333b]">
      <polyline points={coords} fill="none" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
