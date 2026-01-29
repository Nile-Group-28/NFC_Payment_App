
import React, { useState, useEffect } from 'react';
import { Smartphone, QrCode, X, CheckCircle2, AlertCircle, Loader2 } from 'lucide-react';

interface PaymentProps {
  onClose: () => void;
  onSuccess: (amount: number) => void;
}

export const Payment: React.FC<PaymentProps> = ({ onClose, onSuccess }) => {
  const [method, setMethod] = useState<'SELECT' | 'NFC' | 'QR'>('SELECT');
  const [status, setStatus] = useState<'IDLE' | 'PROCESSING' | 'SUCCESS' | 'ERROR'>('IDLE');
  const [amount, setAmount] = useState<string>('');

  const simulatePayment = () => {
    setStatus('PROCESSING');
    setTimeout(() => {
      const isSuccess = Math.random() > 0.1;
      if (isSuccess) {
        setStatus('SUCCESS');
        setTimeout(() => onSuccess(Number(amount)), 2000);
      } else {
        setStatus('ERROR');
      }
    }, 2500);
  };

  const handleNFC = () => {
    setMethod('NFC');
    simulatePayment();
  };

  if (method === 'NFC') {
    return (
      <div className="fixed inset-0 bg-white z-50 flex flex-col items-center justify-center p-8 space-y-12">
        <button onClick={onClose} className="absolute top-6 right-6 p-2 text-slate-400"><X /></button>
        
        {status === 'PROCESSING' && (
          <>
            <div className="relative">
              <div className="w-48 h-48 rounded-full border-4 border-blue-100 border-dashed animate-spin flex items-center justify-center">
              </div>
              <div className="absolute inset-0 flex items-center justify-center">
                <Smartphone size={64} className="text-blue-900" />
              </div>
            </div>
            <div className="text-center space-y-2">
              <h2 className="text-2xl font-bold text-slate-800">Ready to Tap</h2>
              <p className="text-slate-500">Hold your device near the terminal</p>
            </div>
          </>
        )}

        {status === 'SUCCESS' && (
          <>
            <div className="w-24 h-24 bg-green-100 rounded-full flex items-center justify-center text-green-600">
              <CheckCircle2 size={48} />
            </div>
            <div className="text-center space-y-2">
              <h2 className="text-2xl font-bold text-slate-800">Payment Successful</h2>
              <p className="text-slate-500 font-bold text-xl">₦{Number(amount).toLocaleString()}</p>
            </div>
          </>
        )}

        {status === 'ERROR' && (
          <>
            <div className="w-24 h-24 bg-red-100 rounded-full flex items-center justify-center text-red-600">
              <AlertCircle size={48} />
            </div>
            <div className="text-center space-y-2">
              <h2 className="text-2xl font-bold text-slate-800">Connection Failed</h2>
              <p className="text-slate-500">Could not read terminal data. Please try again.</p>
              <button onClick={handleNFC} className="mt-4 bg-blue-950 text-white px-6 py-2 rounded-xl font-bold">RETRY TAP</button>
            </div>
          </>
        )}
      </div>
    );
  }

  return (
    <div className="p-6 space-y-8 h-full flex flex-col bg-slate-50">
      <div className="flex justify-between items-center">
        <h2 className="text-xl font-bold text-slate-800">Make Payment</h2>
        <button onClick={onClose} className="p-2 text-slate-400"><X /></button>
      </div>

      <div className="space-y-4">
        <p className="text-xs font-bold text-slate-400 uppercase tracking-widest">Enter Amount</p>
        <div className="flex items-center gap-2 border-b-2 border-slate-200 pb-2">
          <span className="text-3xl font-bold text-slate-300">₦</span>
          <input 
            type="number" 
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="text-4xl font-bold bg-transparent outline-none flex-1 text-slate-800"
            placeholder="0.00"
            autoFocus
          />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 flex-1 items-end pb-8">
        <button 
          disabled={!amount || Number(amount) <= 0}
          onClick={handleNFC}
          className="flex flex-col items-center gap-3 p-6 bg-blue-950 text-white rounded-2xl shadow-lg shadow-black/10 disabled:opacity-50 disabled:shadow-none transition-all active:scale-95"
        >
          <Smartphone size={32} />
          <span className="font-bold text-sm">Tap to Pay</span>
        </button>

        <button 
          disabled={!amount || Number(amount) <= 0}
          onClick={() => setMethod('QR')}
          className="flex flex-col items-center gap-3 p-6 bg-slate-900 text-white rounded-2xl shadow-lg shadow-black/20 disabled:opacity-50 disabled:shadow-none transition-all active:scale-95"
        >
          <QrCode size={32} />
          <span className="font-bold text-sm">Scan QR</span>
        </button>
      </div>

      {method === 'QR' && (
        <div className="fixed inset-0 bg-slate-950 z-50 p-6 flex flex-col">
          <button onClick={() => setMethod('SELECT')} className="self-end p-2 text-white/50"><X /></button>
          <div className="flex-1 flex flex-col items-center justify-center space-y-8">
            <div className="w-64 h-64 border-2 border-white/20 rounded-3xl relative flex items-center justify-center overflow-hidden">
              <div className="absolute top-0 w-full h-1 bg-blue-500 animate-bounce opacity-50"></div>
              <QrCode size={180} className="text-white opacity-20" />
            </div>
            <p className="text-white font-medium text-center">Center the merchant QR code <br/> within the frame</p>
            <button onClick={() => simulatePayment()} className="bg-white text-slate-900 px-8 py-3 rounded-2xl font-bold">Simulate Scan</button>
          </div>
        </div>
      )}
    </div>
  );
};
