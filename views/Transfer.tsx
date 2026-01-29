
import React, { useState } from 'react';
import { Search, X, User, ArrowRight, CheckCircle2 } from 'lucide-react';
import { PrimaryButton, InputField } from '../components/Widgets';

interface TransferProps {
  onClose: () => void;
  onSuccess: (amount: number, recipient: string) => void;
}

export const Transfer: React.FC<TransferProps> = ({ onClose, onSuccess }) => {
  const [step, setStep] = useState<'SEARCH' | 'AMOUNT' | 'CONFIRM' | 'SUCCESS'>('SEARCH');
  const [query, setQuery] = useState('');
  const [amount, setAmount] = useState('');
  const [selectedUser, setSelectedUser] = useState<string | null>(null);

  if (step === 'SUCCESS') {
    return (
      <div className="fixed inset-0 bg-white z-[90] flex flex-col items-center justify-center p-8 text-center space-y-6">
        <div className="w-24 h-24 bg-blue-50 text-blue-900 rounded-full flex items-center justify-center">
          <CheckCircle2 size={60} />
        </div>
        <h2 className="text-3xl font-black text-slate-900">Transfer Sent!</h2>
        <p className="text-slate-500 font-medium">₦{Number(amount).toLocaleString()} successfully sent to <span className="text-slate-900 font-bold">{selectedUser}</span></p>
        <PrimaryButton label="Done" onClick={onClose} />
      </div>
    );
  }

  return (
    <div className="fixed inset-0 bg-white z-[90] p-6 flex flex-col">
      <div className="flex justify-between items-center mb-8">
        <h2 className="text-xl font-bold text-slate-900">Send Money</h2>
        <button onClick={onClose} className="p-2 text-slate-400"><X /></button>
      </div>

      {step === 'SEARCH' && (
        <div className="space-y-6">
          <InputField 
            label="Search Recipient" 
            placeholder="Search by phone, name or tag" 
            value={query} 
            onChange={setQuery}
            icon={<Search size={20} />}
            autoFocus
          />
          <div className="space-y-4">
            <h3 className="text-xs font-black text-slate-400 uppercase tracking-widest">Recent</h3>
            <div className="space-y-2">
              {['Alice Smith', 'Bob Johnson', 'Chidi Okafor'].map(name => (
                <button 
                  key={name}
                  onClick={() => { setSelectedUser(name); setStep('AMOUNT'); }}
                  className="w-full flex items-center justify-between p-4 bg-white rounded-2xl border border-slate-200 active:bg-slate-50 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-blue-50 text-blue-900 rounded-full flex items-center justify-center"><User size={20}/></div>
                    <span className="font-bold text-slate-800">{name}</span>
                  </div>
                  <ArrowRight size={18} className="text-slate-300" />
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {step === 'AMOUNT' && (
        <div className="space-y-12 flex-1 flex flex-col justify-center">
          <div className="text-center space-y-2">
            <p className="text-slate-400 font-bold uppercase text-xs tracking-widest">Sending to</p>
            <h3 className="text-2xl font-black text-slate-900">{selectedUser}</h3>
          </div>
          <div className="flex items-center justify-center gap-3">
            <span className="text-4xl font-bold text-slate-300">₦</span>
            <input 
              type="number"
              autoFocus
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="text-7xl font-black text-blue-900 outline-none w-full text-center placeholder:text-blue-50"
              placeholder="0"
            />
          </div>
          <PrimaryButton 
            disabled={!amount || Number(amount) <= 0}
            label="Review Transfer" 
            onClick={() => setStep('CONFIRM')} 
          />
        </div>
      )}

      {step === 'CONFIRM' && (
        <div className="space-y-8 flex-1 flex flex-col justify-center">
          <div className="bg-slate-50 p-8 rounded-[2.5rem] space-y-6 border border-slate-100">
             <div className="flex justify-between items-center">
               <span className="text-slate-400 font-medium">To:</span>
               <span className="font-bold text-slate-900">{selectedUser}</span>
             </div>
             <div className="flex justify-between items-center">
               <span className="text-slate-400 font-medium">Amount:</span>
               <span className="font-bold text-slate-900">₦{Number(amount).toLocaleString()}</span>
             </div>
             <div className="flex justify-between items-center">
               <span className="text-slate-400 font-medium">Fee:</span>
               <span className="font-bold text-green-600">Free</span>
             </div>
             <div className="border-t border-slate-200 pt-6 flex justify-between items-center">
               <span className="text-slate-400 font-black uppercase text-xs">Total:</span>
               <span className="text-2xl font-black text-slate-900">₦{Number(amount).toLocaleString()}</span>
             </div>
          </div>
          <PrimaryButton 
            label="Confirm & Send" 
            onClick={() => { setStep('SUCCESS'); setTimeout(() => onSuccess(Number(amount), selectedUser!), 2000); }} 
          />
        </div>
      )}
    </div>
  );
};
