
import React from 'react';
import { ArrowUpRight, QrCode, Smartphone, Bell, ChevronRight, Search } from 'lucide-react';
import { UserProfile, Transaction } from '../types';
import { BalanceCard, TransactionTile } from '../components/Widgets';

interface DashboardProps {
  user: UserProfile;
  transactions: Transaction[];
  onAction: (action: string) => void;
}

const QuickAction: React.FC<{ icon: React.ReactNode; label: string; color: string; onClick: () => void }> = ({ icon, label, color, onClick }) => (
  <button onClick={onClick} className="flex flex-col items-center gap-2 group">
    <div className={`${color} w-14 h-14 rounded-2xl flex items-center justify-center shadow-sm group-active:scale-90 transition-all`}>
      {React.cloneElement(icon as React.ReactElement<any>, { size: 24, strokeWidth: 2.5 })}
    </div>
    <span className="text-[9px] font-black text-slate-500 uppercase tracking-widest">{label}</span>
  </button>
);

export const Dashboard: React.FC<DashboardProps> = ({ user, transactions, onAction }) => {
  return (
    <div className="p-6 space-y-8">
      <BalanceCard balance={user.balance} name={user.name} onTopUp={() => onAction('topup')} />
      <div className="grid grid-cols-4 gap-4">
        <QuickAction icon={<Smartphone />} label="NFC Pay" color="bg-blue-50 text-blue-900" onClick={() => onAction('nfc')} />
        <QuickAction icon={<QrCode />} label="Scan QR" color="bg-emerald-50 text-emerald-600" onClick={() => onAction('qr')} />
        <QuickAction icon={<ArrowUpRight />} label="Send" color="bg-blue-50 text-blue-900" onClick={() => onAction('send')} />
        <QuickAction icon={<Search />} label="Find" color="bg-slate-50 text-slate-600" onClick={() => onAction('find')} />
      </div>
      {user.kycStatus === 'UNVERIFIED' && (
        <div className="bg-amber-50 border border-amber-100 rounded-[2rem] p-6 flex items-center gap-5 group active:bg-amber-100 transition-colors cursor-pointer" onClick={() => onAction('kyc')}>
          <div className="bg-amber-100 p-3 rounded-2xl text-amber-600 group-hover:scale-110 transition-transform"><Bell size={24} /></div>
          <div className="flex-1"><h4 className="text-sm font-black text-amber-900 uppercase tracking-tight">Identity Required</h4><p className="text-xs text-amber-700 font-medium leading-tight">Complete KYC to unlock full limits.</p></div>
          <ChevronRight size={20} className="text-amber-300" />
        </div>
      )}
      <div className="space-y-5">
        <div className="flex justify-between items-center px-1"><h3 className="font-black text-slate-800 uppercase text-xs tracking-widest">Recent Activity</h3><button onClick={() => onAction('history')} className="text-[10px] text-blue-900 font-black uppercase flex items-center gap-1">History <ChevronRight size={14} /></button></div>
        <div className="space-y-3">
          {transactions.slice(0, 3).map((tx) => (
            <TransactionTile key={tx.id} title={tx.description} subtitle={`${new Date(tx.timestamp).toLocaleDateString()} • ${tx.category}`} amount={tx.amount} type={['TOP_UP', 'RECEIVE'].includes(tx.type) ? 'CREDIT' : 'DEBIT'} />
          ))}
        </div>
      </div>
    </div>
  );
};
