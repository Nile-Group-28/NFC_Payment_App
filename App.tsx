
import React, { useState, useEffect } from 'react';
import { Smartphone, Shield, Search, ArrowRightLeft, CreditCard, ChevronDown, XCircle } from 'lucide-react';
import { Layout } from './components/Layout';
import { Dashboard } from './views/Dashboard';
import { Payment } from './views/Payment';
import { SoftPOS } from './views/SoftPOS';
import { Auth } from './views/Auth';
import { SecurityCenter } from './views/Security';
import { AdminDashboard } from './views/Admin';
import { Transfer } from './views/Transfer';
import { Withdrawal } from './views/Withdrawal';
import { TransactionDetail } from './views/TransactionDetail';
import { UserProfile, Transaction, UserRole } from './types';
import { PaystackService } from './services/paystackService';

const INITIAL_TRANSACTIONS: Transaction[] = [
  { id: 'tx_82193', type: 'PAYMENT', amount: 1500, currency: 'NGN', status: 'SUCCESS', timestamp: new Date(Date.now() - 1000 * 60 * 60 * 2), description: 'Starbucks Coffee', category: 'FOOD' },
  { id: 'tx_91283', type: 'TOP_UP', amount: 50000, currency: 'NGN', status: 'SUCCESS', timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24), description: 'Paystack Funding', category: 'OTHER' }
];

export default function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isSplashActive, setIsSplashActive] = useState(true);
  const [activeTab, setActiveTab] = useState('home');
  const [activeRole, setActiveRole] = useState<UserRole>('CONSUMER');
  const [isSecurityCenterOpen, setIsSecurityCenterOpen] = useState(false);
  const [viewState, setViewState] = useState<{ type: 'NONE' | 'TRANSFER' | 'WITHDRAW' | 'TX_DETAIL' | 'KYC'; data?: any; }>({ type: 'NONE' });
  const [transactions, setTransactions] = useState<Transaction[]>(INITIAL_TRANSACTIONS);
  const [user, setUser] = useState<UserProfile>({ 
    id: 'u1', 
    name: 'TAPPAY User', 
    email: '', 
    phone: '', 
    balance: 125400, 
    role: 'CONSUMER', 
    kycStatus: 'UNVERIFIED', 
    isBiometricsEnabled: true, 
    pinCreated: true 
  });

  useEffect(() => {
    const timer = setTimeout(() => setIsSplashActive(false), 2000);
    return () => clearTimeout(timer);
  }, []);

  const handleTransactionSuccess = (amount: number, type: Transaction['type'] = 'PAYMENT', description = 'NFC Payment') => {
    const newTx: Transaction = { id: `tx_${Math.floor(Math.random() * 1000000)}`, type, amount, currency: 'NGN', status: 'SUCCESS', timestamp: new Date(), description, category: 'OTHER' };
    setTransactions(prev => [newTx, ...prev]);
    setUser(prev => ({ ...prev, balance: (type === 'RECEIVE' || type === 'TOP_UP') ? prev.balance + amount : prev.balance - amount }));
    if (activeTab === 'pay') setTimeout(() => setActiveTab('home'), 1000);
  };

  const handleTopUp = async () => {
    const ref = await PaystackService.initializeTransaction(user.email || 'user@example.com', 10000);
    if (await PaystackService.verifyTransaction(ref)) handleTransactionSuccess(10000, 'TOP_UP', 'Paystack Top-up');
  };

  const renderContent = () => {
    if (isSecurityCenterOpen) return <SecurityCenter user={user} onClose={() => setIsSecurityCenterOpen(false)} />;
    if (activeTab === 'pay') return <Payment onClose={() => setActiveTab('home')} onSuccess={(amt) => handleTransactionSuccess(amt)} />;

    switch (activeTab) {
      case 'home':
        if (activeRole === 'MERCHANT') return <SoftPOS onReceive={(amt) => handleTransactionSuccess(amt, 'RECEIVE', 'Soft POS Collection')} />;
        if (activeRole === 'ADMIN') return <AdminDashboard />;
        return <Dashboard user={user} transactions={transactions} onAction={(action) => { if (action === 'topup') handleTopUp(); if (['nfc', 'qr'].includes(action)) setActiveTab('pay'); if (action === 'history') setActiveTab('history'); if (action === 'kyc') setIsSecurityCenterOpen(true); if (action === 'send') setViewState({type: 'TRANSFER'}); }} />;
      case 'history':
        return (
          <div className="p-6 space-y-6">
            <h2 className="text-2xl font-black text-slate-800 tracking-tight">Activity</h2>
            <div className="space-y-4">
              {transactions.map(tx => (
                <div key={tx.id} onClick={() => setViewState({type: 'TX_DETAIL', data: tx})} className="bg-white p-5 rounded-[2rem] border border-slate-50 flex justify-between items-center group active:scale-[0.98] transition-all cursor-pointer shadow-sm">
                  <div className="flex items-center gap-4">
                    <div className="p-3 bg-slate-50 text-slate-800 rounded-2xl"><Smartphone size={20} /></div>
                    <div className="space-y-1"><p className="font-bold text-slate-800 text-sm leading-none">{tx.description}</p><p className="text-[10px] text-slate-400 font-bold uppercase tracking-tight">{tx.type}</p></div>
                  </div>
                  <div className="text-right">
                    <p className={`font-black ${(tx.type === 'TOP_UP' || tx.type === 'RECEIVE') ? 'text-green-600' : 'text-slate-800'}`}>₦{tx.amount.toLocaleString()}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        );
      case 'wallet':
        return (
          <div className="p-6 space-y-8">
            <div className="bg-gradient-to-br from-blue-950 to-slate-900 rounded-[2.5rem] p-8 text-white space-y-8 shadow-2xl overflow-hidden relative group">
               <div className="space-y-1 relative z-10"><p className="text-slate-400 text-[10px] font-black uppercase tracking-widest">Available Balance</p><h2 className="text-5xl font-black tracking-tight">₦{user.balance.toLocaleString()}</h2></div>
               <div className="grid grid-cols-2 gap-4 relative z-10"><button onClick={handleTopUp} className="bg-blue-800 py-4 rounded-2xl font-bold text-sm shadow-xl active:scale-95 transition-all">Add Funds</button><button onClick={() => setViewState({type: 'WITHDRAW'})} className="bg-white/10 py-4 rounded-2xl font-bold text-sm backdrop-blur-md active:scale-95 transition-all">Withdraw</button></div>
            </div>
          </div>
        );
      case 'profile':
        return (
          <div className="p-6 space-y-8">
            <div className="flex items-center gap-6"><div className="w-24 h-24 bg-gradient-to-tr from-blue-900 to-slate-900 rounded-full flex items-center justify-center text-white text-4xl font-black shadow-xl border-4 border-white">DA</div><div><h3 className="text-2xl font-black text-slate-900 tracking-tight">{user.name}</h3><p className="text-xs text-slate-500 font-bold uppercase tracking-widest">Verified Account</p></div></div>
            <div className="bg-white rounded-[2.5rem] border border-slate-100 overflow-hidden shadow-sm">
               <button onClick={() => setActiveRole(activeRole === 'CONSUMER' ? 'MERCHANT' : 'CONSUMER')} className="w-full px-6 py-5 flex items-center justify-between border-b border-slate-50 active:bg-slate-50 transition-colors"><div className="flex items-center gap-4 text-slate-600"><Smartphone size={24} /><div><p className="text-sm font-bold text-slate-800">{activeRole === 'MERCHANT' ? 'Switch to Personal' : 'Activate Soft POS'}</p><p className="text-[10px] text-slate-400 font-bold uppercase tracking-tight">Merchant tools</p></div></div><div className={`w-12 h-6 rounded-full p-1 transition-all ${activeRole === 'MERCHANT' ? 'bg-blue-900' : 'bg-slate-200'}`}><div className={`w-4 h-4 bg-white rounded-full transition-all duration-300 ${activeRole === 'MERCHANT' ? 'translate-x-6' : ''}`} /></div></button>
               <ProfileItem icon={<Shield size={20}/>} label="Security Center" onClick={() => setIsSecurityCenterOpen(true)} />
               <ProfileItem icon={<XCircle size={20} className="text-red-500"/>} label="Logout" danger onClick={() => { setIsAuthenticated(false); setViewState({type: 'NONE'}); }} />
            </div>
          </div>
        );
      default: return <div>Not found</div>;
    }
  };

  if (isSplashActive) return <div className="fixed inset-0 bg-blue-950 flex items-center justify-center z-[100] text-white flex-col gap-6 animate-in fade-in duration-500"><Smartphone size={64} className="animate-bounce" /><h1 className="text-4xl font-black tracking-tighter">TAPPAY</h1></div>;
  if (!isAuthenticated) return <Auth onLogin={() => setIsAuthenticated(true)} />;

  return (
    <Layout activeTab={activeTab} onTabChange={setActiveTab} isMerchantMode={activeRole === 'MERCHANT'}>
      {renderContent()}
      {viewState.type === 'TRANSFER' && <Transfer onClose={() => setViewState({type: 'NONE'})} onSuccess={(amt, r) => handleTransactionSuccess(amt, 'TRANSFER', `To ${r}`)} />}
      {viewState.type === 'WITHDRAW' && <Withdrawal onClose={() => setViewState({type: 'NONE'})} onSuccess={(amt) => handleTransactionSuccess(amt, 'WITHDRAW', 'Bank Settlement')} />}
      {viewState.type === 'TX_DETAIL' && <TransactionDetail transaction={viewState.data} onClose={() => setViewState({type: 'NONE'})} />}
    </Layout>
  );
}

const ProfileItem: React.FC<{ icon: React.ReactNode; label: string; danger?: boolean; onClick?: () => void }> = ({ icon, label, danger, onClick }) => (
  <button onClick={onClick} className="w-full px-6 py-5 flex items-center justify-between border-b border-slate-50 last:border-0 active:bg-slate-50 transition-colors"><div className="flex items-center gap-4"><div className={danger ? 'text-red-500' : 'text-slate-400'}>{icon}</div><span className={`text-sm font-bold ${danger ? 'text-red-500' : 'text-slate-700'}`}>{label}</span></div><ChevronDown size={16} className="-rotate-90 text-slate-300" /></button>
);
