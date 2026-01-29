
import React, { useState } from 'react';
import { X, Landmark, ArrowRight, CheckCircle2 } from 'lucide-react';
import { PrimaryButton, InputField } from '../components/Widgets';

export const Withdrawal: React.FC<{ onClose: () => void; onSuccess: (amount: number) => void }> = ({ onClose, onSuccess }) => {
  const [amount, setAmount] = useState('');
  const [status, setStatus] = useState<'INPUT' | 'PROCESSING' | 'SUCCESS'>('INPUT');

  const handleWithdraw = () => {
    setStatus('PROCESSING');
    setTimeout(() => {
      setStatus('SUCCESS');
      onSuccess(Number(amount));
    }, 2000);
  };

  if (status === 'SUCCESS') {
    return (
      <div className="fixed inset-0 bg-white z-[90] flex flex-col items-center justify-center p-8 text-center space-y-6">
        <div className="w-24 h-24 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center">
          <CheckCircle2 size={60} />
        </div>
        <h2 className="text-3xl font-black text-slate-900">Settled!</h2>
        <p className="text-slate-500 font-medium">₦{Number(amount).toLocaleString()} is on its way to your bank account.</p>
        <PrimaryButton label="Back to Home" onClick={onClose} />
      </div>
    );
  }

  return (
    <div className="fixed inset-0 bg-white z-[90] p-6 flex flex-col">
      <div className="flex justify-between items-center mb-8">
        <h2 className="text-xl font-bold text-slate-900">Withdraw Funds</h2>
        <button onClick={onClose} className="p-2 text-slate-400"><X /></button>
      </div>

      <div className="space-y-8 flex-1">
        <div className="space-y-4">
          <h3 className="text-xs font-black text-slate-400 uppercase tracking-widest">To Account</h3>
          <div className="p-6 bg-slate-50 border border-slate-100 rounded-[2rem] flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-white rounded-2xl flex items-center justify-center shadow-sm"><Landmark className="text-slate-400" size={24}/></div>
              <div>
                <p className="text-sm font-bold text-slate-800">GTBank •••• 4291</p>
                <p className="text-[10px] text-slate-400 font-bold uppercase">Savings Account</p>
              </div>
            </div>
            <ArrowRight className="text-slate-300" size={20} />
          </div>
        </div>

        <InputField 
          label="Enter Amount" 
          placeholder="0" 
          type="number" 
          value={amount} 
          onChange={setAmount}
          prefix="₦"
          autoFocus
        />

        <div className="p-4 bg-blue-50 rounded-2xl border border-blue-100 flex gap-4">
          <div className="text-blue-600 mt-1"><CheckCircle2 size={16}/></div>
          <p className="text-xs text-blue-800 leading-relaxed">Withdrawals to linked NexaPay verified accounts are usually processed within 2-4 hours.</p>
        </div>
      </div>

      <PrimaryButton 
        loading={status === 'PROCESSING'}
        disabled={!amount || Number(amount) <= 0}
        label="Withdraw to Bank" 
        onClick={handleWithdraw} 
      />
    </div>
  );
};
