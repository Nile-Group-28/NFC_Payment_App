
import React from 'react';
import { X, Share2, Download, ShieldCheck, ArrowUpRight, ArrowDownLeft } from 'lucide-react';
import { Transaction } from '../types';
import { PrimaryButton } from '../components/Widgets';

export const TransactionDetail: React.FC<{ transaction: Transaction; onClose: () => void }> = ({ transaction, onClose }) => {
  const isCredit = transaction.type === 'TOP_UP' || transaction.type === 'RECEIVE';

  return (
    <div className="fixed inset-0 bg-white z-[95] p-6 flex flex-col">
      <div className="flex justify-between items-center mb-8">
        <h2 className="text-xl font-bold text-slate-900">Receipt</h2>
        <button onClick={onClose} className="p-2 text-slate-400"><X /></button>
      </div>

      <div className="flex-1 overflow-y-auto no-scrollbar pb-8">
        <div className="bg-slate-50 rounded-[2.5rem] p-8 text-center space-y-6 relative overflow-hidden">
          <div className={`w-20 h-20 rounded-full mx-auto flex items-center justify-center ${isCredit ? 'bg-emerald-100 text-emerald-600' : 'bg-blue-100 text-blue-600'}`}>
            {isCredit ? <ArrowDownLeft size={32} /> : <ArrowUpRight size={32} />}
          </div>
          
          <div className="space-y-1">
            <h3 className="text-4xl font-black text-slate-900 tracking-tight">
              {isCredit ? '+' : '-'}₦{transaction.amount.toLocaleString()}
            </h3>
            <div className="flex items-center justify-center gap-2">
              <span className="w-2 h-2 bg-green-500 rounded-full"></span>
              <p className="text-xs font-black text-slate-400 uppercase tracking-widest">Transaction Successful</p>
            </div>
          </div>

          <div className="border-t border-dashed border-slate-200 pt-6 space-y-4 text-sm text-left">
            <DetailRow label="Transaction ID" value={transaction.id.toUpperCase()} />
            <DetailRow label="Type" value={transaction.type} />
            <DetailRow label="Description" value={transaction.description} />
            <DetailRow label="Category" value={transaction.category} />
            <DetailRow label="Date" value={transaction.timestamp.toLocaleDateString()} />
            <DetailRow label="Time" value={transaction.timestamp.toLocaleTimeString()} />
          </div>
        </div>

        <div className="mt-8 flex items-center gap-4 p-5 bg-blue-50 border border-blue-100 rounded-2xl">
          <ShieldCheck className="text-blue-600" size={24} />
          <p className="text-[10px] text-blue-800 font-bold uppercase tracking-tight">This transaction is protected by NexaGuard™ 256-bit encryption.</p>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <PrimaryButton variant="secondary" label="Share" onClick={() => {}} icon={<Share2 size={18}/>} />
        <PrimaryButton variant="secondary" label="Download" onClick={() => {}} icon={<Download size={18}/>} />
      </div>
    </div>
  );
};

const DetailRow: React.FC<{ label: string; value: string }> = ({ label, value }) => (
  <div className="flex justify-between items-center">
    <span className="text-slate-400 font-medium">{label}</span>
    <span className="font-bold text-slate-900">{value}</span>
  </div>
);
