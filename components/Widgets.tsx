
import React, { useRef, useEffect } from 'react';
import { ChevronRight, Loader2, CreditCard } from 'lucide-react';

interface ButtonProps {
  label: string;
  onClick: () => void;
  disabled?: boolean;
  loading?: boolean;
  icon?: React.ReactNode;
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  fullWidth?: boolean;
}

export const PrimaryButton: React.FC<ButtonProps> = ({ 
  label, onClick, disabled, loading, icon, variant = 'primary', fullWidth = true 
}) => {
  const baseStyles = "flex items-center justify-center gap-2 py-4 px-6 rounded-2xl font-bold text-lg transition-all active:scale-95 disabled:opacity-50 disabled:active:scale-100";
  
  const variants = {
    primary: "bg-blue-950 text-white shadow-lg shadow-black/10 hover:bg-slate-900",
    secondary: "bg-slate-100 text-slate-800",
    danger: "bg-red-50 text-red-600",
    ghost: "bg-transparent text-blue-950"
  };

  return (
    <button 
      onClick={onClick} 
      disabled={disabled || loading} 
      className={`${baseStyles} ${variants[variant]} ${fullWidth ? 'w-full' : ''}`}
    >
      {loading ? <Loader2 className="animate-spin" size={20} /> : (
        <>
          {icon}
          {label}
        </>
      )}
    </button>
  );
};

export const InputField: React.FC<{
  label: string;
  placeholder?: string;
  type?: string;
  value: string;
  onChange: (val: string) => void;
  icon?: React.ReactNode;
  prefix?: string;
  id?: string;
  autoFocus?: boolean;
}> = ({ label, placeholder, type = 'text', value, onChange, icon, prefix, id, autoFocus }) => {
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (autoFocus && inputRef.current) {
      inputRef.current.focus();
    }
  }, [autoFocus]);

  return (
    <div className="space-y-2">
      <label htmlFor={id} className="text-[10px] font-black text-slate-400 uppercase tracking-widest px-1">
        {label}
      </label>
      <div 
        onClick={() => inputRef.current?.focus()}
        className="flex items-center gap-3 bg-white px-4 py-4 rounded-2xl border border-slate-200 focus-within:border-blue-950 focus-within:ring-2 focus-within:ring-blue-950/5 transition-all cursor-text"
      >
        {icon && <div className="text-slate-400 shrink-0">{icon}</div>}
        <div className="flex-1 flex items-center gap-1.5">
          {prefix && (
            <span className="text-slate-900 font-black text-lg select-none">
              {prefix}
            </span>
          )}
          <input 
            id={id}
            ref={inputRef}
            type={type} 
            value={value}
            onChange={(e) => onChange(e.target.value)}
            placeholder={placeholder}
            autoFocus={autoFocus}
            className="bg-transparent outline-none flex-1 text-slate-800 font-semibold placeholder:text-slate-300 text-base min-h-[24px] w-full"
          />
        </div>
      </div>
    </div>
  );
};

export const BalanceCard: React.FC<{ balance: number; name: string; onTopUp: () => void }> = ({ balance, name, onTopUp }) => (
  <div className="bg-gradient-to-br from-blue-900 via-blue-950 to-slate-950 rounded-[2.5rem] p-8 text-white shadow-2xl relative overflow-hidden group">
    <div className="absolute top-0 right-0 p-8 opacity-10 rotate-12 group-hover:rotate-0 transition-transform duration-700 scale-150">
      <CreditCard size={100} />
    </div>
    <div className="space-y-1 relative z-10">
      <p className="text-blue-200/60 text-[10px] font-black uppercase tracking-widest">Active Balance</p>
      <h2 className="text-4xl font-black tracking-tight">₦{balance.toLocaleString()}</h2>
    </div>
    <div className="flex justify-between items-end mt-10 relative z-10">
      <div>
        <p className="text-[10px] text-blue-200/60 uppercase tracking-widest font-black">Account Holder</p>
        <p className="font-bold text-lg">{name}</p>
      </div>
      <button 
        onClick={onTopUp}
        className="bg-white text-blue-950 px-5 py-2.5 rounded-xl text-sm font-black transition-all hover:bg-blue-50 active:scale-90 shadow-xl"
      >
        Top up
      </button>
    </div>
  </div>
);

export const TransactionTile: React.FC<{ 
  title: string; 
  subtitle: string; 
  amount: number; 
  type: 'CREDIT' | 'DEBIT';
  onClick?: () => void;
}> = ({ title, subtitle, amount, type, onClick }) => (
  <div 
    onClick={onClick}
    className="bg-white p-5 rounded-[2rem] flex items-center justify-between border border-slate-100 shadow-sm active:scale-[0.98] transition-all cursor-pointer"
  >
    <div className="flex items-center gap-4">
      <div className={`p-3 rounded-2xl ${type === 'CREDIT' ? 'bg-emerald-50 text-emerald-600' : 'bg-slate-50 text-slate-800'}`}>
        <div className={`w-5 h-5 flex items-center justify-center font-bold text-lg`}>
          {type === 'CREDIT' ? '+' : '-'}
        </div>
      </div>
      <div>
        <p className="font-bold text-sm text-slate-800 leading-none mb-1">{title}</p>
        <p className="text-[10px] text-slate-400 font-bold uppercase tracking-tight">{subtitle}</p>
      </div>
    </div>
    <div className="text-right">
      <p className={`font-black ${type === 'CREDIT' ? 'text-emerald-600' : 'text-slate-800'}`}>
        ₦{amount.toLocaleString()}
      </p>
      <ChevronRight size={14} className="text-slate-200 inline ml-auto" />
    </div>
  </div>
);
