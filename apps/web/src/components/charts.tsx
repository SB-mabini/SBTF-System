"use client";

import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

import type {
  DocumentComplianceRow,
  ProcessingTimePoint,
  TodaAnalytics,
  TrendPoint,
} from "@/types/database";
import { DOCUMENT_SHORT_LABELS } from "@/lib/constants";

const AXIS = { fontSize: 11, fill: "#6b7280" } as const;

const tooltipStyle = {
  borderRadius: 8,
  border: "1px solid #e5e7eb",
  fontSize: 12,
  boxShadow: "0 4px 12px -2px rgb(22 18 19 / 0.08)",
} as const;

function ChartFrame({
  height = 260,
  children,
}: {
  height?: number;
  children: React.ReactElement;
}) {
  return (
    <div style={{ width: "100%", height }}>
      <ResponsiveContainer width="100%" height="100%">
        {children}
      </ResponsiveContainer>
    </div>
  );
}

/** Application volume with new / renewal split. */
export function ApplicationTrendChart({ data }: { data: TrendPoint[] }) {
  return (
    <ChartFrame>
      <AreaChart data={data} margin={{ top: 8, right: 8, left: -18, bottom: 0 }}>
        <defs>
          <linearGradient id="submittedFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#271564" stopOpacity={0.22} />
            <stop offset="100%" stopColor="#271564" stopOpacity={0.02} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" vertical={false} />
        <XAxis dataKey="month_label" tick={AXIS} tickLine={false} axisLine={false} />
        <YAxis tick={AXIS} tickLine={false} axisLine={false} allowDecimals={false} />
        <Tooltip contentStyle={tooltipStyle} />
        <Legend wrapperStyle={{ fontSize: 11 }} />
        <Area
          type="monotone"
          dataKey="submitted"
          name="Submitted"
          stroke="#271564"
          strokeWidth={2}
          fill="url(#submittedFill)"
        />
        <Line
          type="monotone"
          dataKey="approved"
          name="Approved"
          stroke="#0f7a4a"
          strokeWidth={2}
          dot={false}
        />
        <Line
          type="monotone"
          dataKey="rejected"
          name="Rejected"
          stroke="#d4271d"
          strokeWidth={2}
          dot={false}
        />
      </AreaChart>
    </ChartFrame>
  );
}

/** New versus renewal volume. */
export function ApplicationTypeChart({ data }: { data: TrendPoint[] }) {
  return (
    <ChartFrame height={240}>
      <BarChart data={data} margin={{ top: 8, right: 8, left: -18, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" vertical={false} />
        <XAxis dataKey="month_label" tick={AXIS} tickLine={false} axisLine={false} />
        <YAxis tick={AXIS} tickLine={false} axisLine={false} allowDecimals={false} />
        <Tooltip contentStyle={tooltipStyle} />
        <Legend wrapperStyle={{ fontSize: 11 }} />
        <Bar dataKey="new_count" name="New" stackId="a" fill="#271564" radius={[0, 0, 0, 0]} />
        <Bar dataKey="renewal_count" name="Renewal" stackId="a" fill="#F2C749" radius={[3, 3, 0, 0]} />
      </BarChart>
    </ChartFrame>
  );
}

/** Applications per TODA — horizontal comparison, top 10 only. */
export function TodaComparisonChart({ data }: { data: TodaAnalytics[] }) {
  const top = data.slice(0, 10).map((row) => ({
    ...row,
    short_name: row.toda_name.replace(/^TODA\s+/, ""),
  }));

  return (
    <ChartFrame height={300}>
      <BarChart data={top} layout="vertical" margin={{ top: 4, right: 16, left: 8, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" horizontal={false} />
        <XAxis type="number" tick={AXIS} tickLine={false} axisLine={false} allowDecimals={false} />
        <YAxis
          type="category"
          dataKey="short_name"
          width={110}
          tick={AXIS}
          tickLine={false}
          axisLine={false}
        />
        <Tooltip contentStyle={tooltipStyle} />
        <Legend wrapperStyle={{ fontSize: 11 }} />
        <Bar dataKey="approved" name="Approved" stackId="s" fill="#271564" />
        <Bar dataKey="pending" name="Pending" stackId="s" fill="#F2C749" />
        <Bar dataKey="rejected" name="Rejected" stackId="s" fill="#d4271d" radius={[0, 3, 3, 0]} />
      </BarChart>
    </ChartFrame>
  );
}

/** Processing-time trend with the 5-day service target marked. */
export function ProcessingTimeChart({ data }: { data: ProcessingTimePoint[] }) {
  return (
    <ChartFrame height={240}>
      <LineChart data={data} margin={{ top: 8, right: 8, left: -18, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" vertical={false} />
        <XAxis dataKey="month_label" tick={AXIS} tickLine={false} axisLine={false} />
        <YAxis tick={AXIS} tickLine={false} axisLine={false} unit="d" />
        <Tooltip contentStyle={tooltipStyle} />
        <Legend wrapperStyle={{ fontSize: 11 }} />
        <Line
          type="monotone"
          dataKey="avg_days"
          name="Average days"
          stroke="#271564"
          strokeWidth={2}
          dot={{ r: 2 }}
        />
        <Line
          type="monotone"
          dataKey="median_days"
          name="Median days"
          stroke="#6b7280"
          strokeWidth={2}
          strokeDasharray="4 3"
          dot={false}
        />
      </LineChart>
    </ChartFrame>
  );
}

/** Decision mix as a donut: approved / pending / rejected. */
export function DecisionMixChart({
  approved,
  pending,
  rejected,
}: {
  approved: number;
  pending: number;
  rejected: number;
}) {
  const data = [
    { name: "Approved", value: approved, fill: "#271564" },
    { name: "Pending", value: pending, fill: "#F2C749" },
    { name: "Rejected", value: rejected, fill: "#d4271d" },
  ];

  return (
    <ChartFrame height={240}>
      <PieChart>
        <Pie
          data={data}
          dataKey="value"
          nameKey="name"
          innerRadius={58}
          outerRadius={88}
          paddingAngle={2}
          strokeWidth={0}
        >
          {data.map((entry) => (
            <Cell key={entry.name} fill={entry.fill} />
          ))}
        </Pie>
        <Tooltip contentStyle={tooltipStyle} />
        <Legend wrapperStyle={{ fontSize: 11 }} />
      </PieChart>
    </ChartFrame>
  );
}

/** Documentary requirement compliance rate. */
export function DocumentComplianceChart({ data }: { data: DocumentComplianceRow[] }) {
  const rows = data.map((row) => ({
    ...row,
    label: DOCUMENT_SHORT_LABELS[row.document_type].replace(" (Official Receipt & Certificate of Registration)", ""),
  }));

  return (
    <ChartFrame height={240}>
      <BarChart data={rows} margin={{ top: 8, right: 8, left: -18, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" vertical={false} />
        <XAxis dataKey="label" tick={{ ...AXIS, fontSize: 10 }} tickLine={false} axisLine={false} interval={0} />
        <YAxis tick={AXIS} tickLine={false} axisLine={false} unit="%" domain={[0, 100]} />
        <Tooltip contentStyle={tooltipStyle} />
        <Bar dataKey="verified_rate" name="Verified" fill="#271564" radius={[3, 3, 0, 0]} barSize={38} />
      </BarChart>
    </ChartFrame>
  );
}
