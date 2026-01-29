
import React, { useState } from 'react';
import { Smartphone, CheckCircle2, ChevronRight, BarChart3, Users, Settings, ArrowUpRight, ArrowDownLeft, Store, Layers, TrendingUp, X } from 'lucide-react';

interface SoftPOSProps {
  onReceive: (amount: number) => void;
}

export const SoftPOS: React.FC<SoftPOSProps> = ({ onReceive }) => {
  const [amount, setAmount] = useState<string>('');
  const [status, setStatus] = useState<'SETUP' | 'DASHBOARD' | 'INPUT' | 'WAITING' | 'SUCCESS'>('SETUP');

  const startReceiving = () => {
    setStatus('WAITING');
    setTimeout(() => {
      setStatus('SUCCESS');
      onReceive(Number(amount));
    }, 4000);
  };

  if (status === 'SETUP') {
    return (
      <div className="h-full bg-white flex flex-col p-8">
        <div className="flex-1 flex flex-col justify-center items-center text-center space-y-8">
          <div className="w-24 h-24 bg-blue-50 text-blue-900 rounded-[2.5rem] flex items-center justify-center">
            <Store size={48} />
          </div>
          <div className="space-y-3">
            <h2 className="text-3xl font-black text-slate-900 tracking-tight">Activate Soft POS</h2>
            <p className="text-slate-500 font-medium">Turn your smartphone into a secure payment terminal. Accept NFC cards and QR codes instantly.</p>
          </div>
          <ul className="text-left w-full space-y-4">
            <SetupFeature icon={<TrendingUp size={20}/>} text="Accept all major local cards" />
            <SetupFeature icon={<Layers size={20}/>} text="Real-time business analytics" />
            <SetupFeature icon={<CheckCircle2 size={20}/>} text="Same-day settlements" />
          </ul>
        </div>
        <button 
          onClick={() => setStatus('DASHBOARD')}
          className="w-full bg-blue-900 text-white py-5 rounded-2xl font-bold text-lg shadow-xl shadow-black/10"
        >
          Begin Setup
        </button>
      </div>
    );
  }

  if (status === 'WAITING') {
    return (
      <div className="h-full bg-slate-950 flex flex-col items-center justify-center p-8 text-center space-y-8">
        <div className="relative">
          <div className="w-48 h-48 rounded-full border-4 border-blue-800/30 border-dashed animate-spin"></div>
          <div className="absolute inset-0 flex items-center justify-center">
            <Smartphone size={64} className="text-blue-400" />
          </div>
        </div>
        <div className="space-y-2">
          <h2 className="text-2xl font-bold text-white">Terminal Active</h2>
          <p className="text-slate-400">Ask the customer to tap their card <br/> or phone against your device</p>
          <div className="mt-8 bg-blue-900/40 text-blue-200 px-6 py-3 rounded-2xl inline-block font-mono text-3xl font-bold border border-blue-800/50">
            ₦{Number(amount).toLocaleString()}
          </div>
        </div>
        <button onClick={() => setStatus('DASHBOARD')} className="text-slate-500 font-bold text-sm uppercase tracking-widest hover:text-white transition-colors">Cancel Session</button>
      </div>
    );
  }

  if (status === 'SUCCESS') {
    return (
      <div className="h-full bg-blue-950 flex flex-col items-center justify-center p-8 text-center space-y-6 text-white">
        <div className="w-24 h-24 bg-white/10 rounded-full flex items-center justify-center">
          <CheckCircle2 size={60} />
        </div>
        <div className="space-y-2">
          <h2 className="text-4xl font-black">Success!</h2>
          <p className="text-blue-100 text-xl font-medium opacity-80">Payment of ₦{Number(amount).toLocaleString()} received</p>
        </div>
        <div className="w-full max-w-xs bg-black/20 rounded-3xl p-6 text-left space-y-2 border border-white/10">
          <p className="text-[10px] font-black tracking-widest opacity-50 uppercase">Digital Receipt</p>
          <div className="flex justify-between text-sm"><span>Reference:</span> <span className="font-mono">T-4891-XP</span></div>
          <div className="flex justify-between text-sm"><span>Date:</span> <span>{new Date().toLocaleDateString()}</span></div>
        </div>
        <button 
          onClick={() => { setAmount(''); setStatus('DASHBOARD'); }} 
          className="mt-12 bg-white text-blue-950 w-full max-w-xs py-4 rounded-2xl font-bold text-lg shadow-2xl active:scale-95 transition-all"
        >
          New Transaction
        </button>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6 flex flex-col min-h-full">
      {/* Analytics Summary */}
      <div className="space-y-4">
        <div className="flex justify-between items-center">
          <h2 className="text-xl font-bold text-slate-800">Business Hub</h2>
          <div className="flex items-center gap-2 bg-blue-50 text-blue-900 px-3 py-1 rounded-lg text-xs font-bold">
            <span className="w-2 h-2 bg-blue-900 rounded-full animate-pulse"></span> Terminal Online
          </div>
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div className="bg-white p-5 rounded-[2rem] border border-slate-100 shadow-sm">
            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Total Sales</p>
            <p className="text-2xl font-black text-slate-800">₦42k</p>
            <div className="mt-2 text-[10px] text-green-500 font-bold flex items-center">
              <TrendingUp size={12} className="mr-1" /> +12% today
            </div>
          </div>
          <div className="bg-white p-5 rounded-[2rem] border border-slate-100 shadow-sm">
            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Customers</p>
            <p className="text-2xl font-black text-slate-800">18</p>
            <div className="mt-2 text-[10px] text-blue-900 font-bold">New: 4</div>
          </div>
        </div>
      </div>

      {/* Main Collection Button */}
      <button 
        onClick={() => setStatus('INPUT')}
        className="w-full bg-blue-900 rounded-[2.5rem] p-8 text-white shadow-2xl shadow-black/10 text-left relative overflow-hidden group active:scale-95 transition-all"
      >
        <div className="absolute -right-8 -bottom-8 w-40 h-40 bg-white/5 rounded-full group-hover:scale-110 transition-transform"></div>
        <Smartphone className="mb-4 text-blue-200" size={32} />
        <h3 className="text-2xl font-black leading-tight">Collect <br/> Payment</h3>
        <p className="text-blue-100 text-sm font-medium mt-1 opacity-80">NFC Tap or QR Scan</p>
      </button>

      {/* Amount Input (Overlay mode) */}
      {status === 'INPUT' && (
        <div className="fixed inset-0 bg-white z-[80] p-6 flex flex-col">
          <div className="flex justify-between items-center mb-12">
            <h2 className="text-xl font-bold text-slate-900">Enter Amount</h2>
            <button onClick={() => setStatus('DASHBOARD')} className="p-2 text-slate-400"><X /></button>
          </div>
          <div className="flex-1 flex flex-col justify-center items-center">
             <div className="flex items-center gap-3">
               <span className="text-4xl font-bold text-slate-300">₦</span>
               <input 
                 type="number"
                 placeholder="0"
                 autoFocus
                 value={amount}
                 onChange={(e) => setAmount(e.target.value)}
                 className="text-7xl font-black text-blue-900 outline-none w-full text-center placeholder:text-blue-50"
               />
             </div>
          </div>
          <button 
            disabled={!amount || Number(amount) <= 0}
            onClick={startReceiving}
            className="w-full bg-blue-900 text-white py-5 rounded-[2rem] font-bold text-lg shadow-xl disabled:opacity-50"
          >
            Open Terminal
          </button>
        </div>
      )}

      {/* Tools Grid */}
      <div className="space-y-4">
        <h3 className="text-sm font-bold text-slate-400 uppercase tracking-widest">Management</h3>
        <div className="grid grid-cols-3 gap-3">
          <ToolItem icon={<BarChart3 size={20}/>} label="Analytics" />
          <ToolItem icon={<Users size={20}/>} label="Settlements" />
          <ToolItem icon={<Settings size={20}/>} label="Settings" />
        </div>
      </div>

      {/* Recent Merchant Transactions */}
      <div className="space-y-4 pt-2">
        <h3 className="text-sm font-bold text-slate-400 uppercase tracking-widest">Recent Collections</h3>
        <div className="space-y-2">
          <MerchantTx amount={2400} time="10:45 AM" type="NFC" />
          <MerchantTx amount={12500} time="09:12 AM" type="QR" />
          <MerchantTx amount={800} time="Yesterday" type="NFC" />
        </div>
      </div>
    </div>
  );
};

const SetupFeature: React.FC<{ icon: React.ReactNode; text: string }> = ({ icon, text }) => (
  <li className="flex items-center gap-3">
    <div className="text-blue-900">{icon}</div>
    <span className="text-sm font-bold text-slate-700">{text}</span>
  </li>
);

const ToolItem: React.FC<{ icon: React.ReactNode; label: string }> = ({ icon, label }) => (
  <button className="flex flex-col items-center gap-2 p-5 bg-white rounded-3xl border border-slate-100 active:bg-slate-50 shadow-sm transition-all">
    <div className="text-blue-900">{icon}</div>
    <span className="text-[10px] font-black text-slate-500 uppercase tracking-tight">{label}</span>
  </button>
);

const MerchantTx: React.FC<{ amount: number; time: string; type: string }> = ({ amount, time, type }) => (
  <div className="bg-white p-4 rounded-2xl border border-slate-50 flex items-center justify-between">
    <div className="flex items-center gap-3">
      <div className="w-10 h-10 bg-slate-50 text-blue-900 rounded-xl flex items-center justify-center font-black text-xs">
        {type}
      </div>
      <div>
        <p className="text-sm font-bold text-slate-800">Payment Received</p>
        <p className="text-[10px] text-slate-400 font-bold uppercase">{time}</p>
      </div>
    </div>
    <p className="font-black text-slate-800">₦{amount.toLocaleString()}</p>
  </div>
);
