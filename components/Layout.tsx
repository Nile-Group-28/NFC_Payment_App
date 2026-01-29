
import React from 'react';
import { Home, CreditCard, History, User, Smartphone, Plus } from 'lucide-react';

interface LayoutProps {
  children: React.ReactNode;
  activeTab: string;
  onTabChange: (tab: string) => void;
  isMerchantMode?: boolean;
}

export const Layout: React.FC<LayoutProps> = ({ children, activeTab, onTabChange, isMerchantMode }) => {
  return (
    <div className="flex flex-col h-screen max-w-md mx-auto bg-white shadow-xl relative overflow-hidden">
      {/* Dynamic Header */}
      <header className="px-6 py-4 flex justify-between items-center bg-white border-b border-slate-100 z-10">
        <h1 className="text-xl font-bold text-slate-800">
          {isMerchantMode ? 'Soft POS' : 'TAPPAY'}
        </h1>
        <div className="flex gap-2">
          <div className={`px-2 py-1 rounded text-[10px] font-bold tracking-wider ${isMerchantMode ? 'bg-blue-100 text-blue-900' : 'bg-green-100 text-green-600'}`}>
            {isMerchantMode ? 'MERCHANT' : 'PERSONAL'}
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="flex-1 overflow-y-auto no-scrollbar bg-slate-50">
        {children}
      </main>

      {/* Persistent Bottom Navigation */}
      <nav className="bg-white border-t border-slate-100 px-4 py-2 flex justify-around items-center z-10">
        <NavItem 
          icon={<Home size={22} />} 
          label="Home" 
          active={activeTab === 'home'} 
          onClick={() => onTabChange('home')} 
        />
        <NavItem 
          icon={<History size={22} />} 
          label="Activity" 
          active={activeTab === 'history'} 
          onClick={() => onTabChange('history')} 
        />
        
        {/* Central Pay Button */}
        <button 
          onClick={() => onTabChange('pay')}
          className="bg-blue-950 text-white p-3 rounded-full -mt-8 shadow-lg shadow-black/20 active:scale-95 transition-transform"
        >
          <Smartphone size={24} />
        </button>

        <NavItem 
          icon={<CreditCard size={22} />} 
          label="Wallet" 
          active={activeTab === 'wallet'} 
          onClick={() => onTabChange('wallet')} 
        />
        <NavItem 
          icon={<User size={22} />} 
          label="Profile" 
          active={activeTab === 'profile'} 
          onClick={() => onTabChange('profile')} 
        />
      </nav>
    </div>
  );
};

const NavItem: React.FC<{ icon: React.ReactNode; label: string; active: boolean; onClick: () => void }> = ({ icon, label, active, onClick }) => (
  <button 
    onClick={onClick}
    className={`flex flex-col items-center gap-1 transition-colors ${active ? 'text-blue-950' : 'text-slate-400'}`}
  >
    {icon}
    <span className="text-[10px] font-bold">{label}</span>
  </button>
);
