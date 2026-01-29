
import React from 'react';
import { LayoutDashboard, Users, Activity, ShieldCheck, Database, Server, RefreshCw, ChevronRight } from 'lucide-react';

export const AdminDashboard: React.FC = () => {
  return (
    <div className="p-6 space-y-8 bg-slate-900 min-h-full text-white">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-2xl font-black tracking-tight">System Admin</h2>
          <p className="text-slate-400 text-xs font-medium">Node: NEXA-NG-01-PROD</p>
        </div>
        <div className="p-2 bg-green-500/20 text-green-400 rounded-lg">
          <Server size={20} />
        </div>
      </div>

      {/* Global Metrics */}
      <div className="grid grid-cols-2 gap-4">
        <MetricCard label="Total Volume" value="₦2.4B" trend="+4.2%" color="text-blue-400" />
        <MetricCard label="Active Users" value="1.2M" trend="+0.8%" color="text-purple-400" />
        <MetricCard label="Success Rate" value="99.9%" trend="Stable" color="text-green-400" />
        <MetricCard label="KYC Backlog" value="4.8k" trend="-12%" color="text-amber-400" />
      </div>

      {/* Admin Modules */}
      <div className="space-y-4">
        <h3 className="text-xs font-black text-slate-500 uppercase tracking-widest">Control Modules</h3>
        <div className="grid grid-cols-2 gap-4">
          <AdminModule icon={<Users />} label="User Registry" count="1,248,912" />
          <AdminModule icon={<Activity />} label="Live Transactions" count="482 tx/m" />
          <AdminModule icon={<ShieldCheck />} label="Fraud Engine" count="0 Threats" />
          <AdminModule icon={<Database />} label="Settlement Logs" count="32 Nodes" />
        </div>
      </div>

      {/* System Health */}
      <div className="bg-slate-800/50 rounded-[2rem] p-6 space-y-6">
        <div className="flex justify-between items-center">
          <h3 className="font-bold">System Health</h3>
          <RefreshCw size={16} className="text-slate-500" />
        </div>
        <div className="space-y-4">
          <HealthBar label="Database Cluster" status="Healthy" percent={94} />
          <HealthBar label="Paystack Gateway" status="Latency: 12ms" percent={88} />
          <HealthBar label="NFC Validation Node" status="Healthy" percent={100} />
        </div>
      </div>
    </div>
  );
};

const MetricCard: React.FC<{ label: string; value: string; trend: string; color: string }> = ({ label, value, trend, color }) => (
  <div className="bg-slate-800 rounded-3xl p-5 border border-white/5">
    <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mb-2">{label}</p>
    <p className={`text-2xl font-black ${color}`}>{value}</p>
    <p className="text-[10px] font-bold text-slate-400 mt-1">{trend} this week</p>
  </div>
);

const AdminModule: React.FC<{ icon: React.ReactNode; label: string; count: string }> = ({ icon, label, count }) => (
  <button className="bg-white/5 p-5 rounded-3xl border border-white/5 text-left space-y-3 active:scale-95 transition-all">
    <div className="text-blue-400">{icon}</div>
    <div>
      <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest">{label}</p>
      <p className="text-sm font-bold text-white mt-0.5">{count}</p>
    </div>
  </button>
);

const HealthBar: React.FC<{ label: string; status: string; percent: number }> = ({ label, status, percent }) => (
  <div className="space-y-2">
    <div className="flex justify-between text-[10px] font-bold uppercase tracking-wider">
      <span className="text-slate-300">{label}</span>
      <span className="text-slate-500">{status}</span>
    </div>
    <div className="h-1.5 w-full bg-slate-700 rounded-full overflow-hidden">
      <div className={`h-full rounded-full transition-all duration-1000 ${percent > 90 ? 'bg-green-500' : percent > 70 ? 'bg-blue-500' : 'bg-amber-500'}`} style={{ width: `${percent}%` }}></div>
    </div>
  </div>
);
