
import React, { useState } from 'react';
import { Shield, Fingerprint, Lock, Bell, AlertTriangle, FileCheck, UserCheck, ChevronRight, X, Camera } from 'lucide-react';
import { UserProfile, Alert } from '../types';

interface SecurityProps {
  user: UserProfile;
  onClose: () => void;
}

export const SecurityCenter: React.FC<SecurityProps> = ({ user, onClose }) => {
  const [kycFormActive, setKycFormActive] = useState(false);
  const [alerts] = useState<Alert[]>([
    {
      id: '1',
      title: 'New Login Detected',
      message: 'A new login occurred from iPhone 15 in Lagos, Nigeria.',
      type: 'INFO',
      timestamp: new Date()
    },
    {
      id: '2',
      title: 'Biometrics Enabled',
      message: 'You have successfully activated Face ID for transactions.',
      type: 'INFO',
      timestamp: new Date(Date.now() - 3600000)
    }
  ]);

  const KycForm = () => (
    <div className="fixed inset-0 bg-white z-[70] p-6 flex flex-col">
      <div className="flex justify-between items-center mb-8">
        <h2 className="text-xl font-bold text-slate-900">Identity Verification</h2>
        <button onClick={() => setKycFormActive(false)} className="p-2 text-slate-400"><X /></button>
      </div>
      
      <div className="space-y-8 flex-1 overflow-y-auto no-scrollbar">
        <div className="space-y-4">
          <h3 className="text-sm font-bold text-slate-400 uppercase tracking-widest">Step 1: Document Upload</h3>
          <div className="grid grid-cols-2 gap-4">
            <button className="aspect-video bg-slate-50 border-2 border-dashed border-slate-200 rounded-2xl flex flex-col items-center justify-center gap-2 text-slate-400">
              <Camera size={24} />
              <span className="text-[10px] font-bold">FRONT SIDE</span>
            </button>
            <button className="aspect-video bg-slate-50 border-2 border-dashed border-slate-200 rounded-2xl flex flex-col items-center justify-center gap-2 text-slate-400">
              <Camera size={24} />
              <span className="text-[10px] font-bold">BACK SIDE</span>
            </button>
          </div>
        </div>

        <div className="space-y-4">
          <h3 className="text-sm font-bold text-slate-400 uppercase tracking-widest">Step 2: Liveness Check</h3>
          <div className="w-full aspect-square bg-slate-900 rounded-[2.5rem] relative flex items-center justify-center overflow-hidden">
             <div className="w-48 h-48 border-2 border-blue-500/50 rounded-full border-dashed animate-pulse"></div>
             <p className="absolute bottom-6 text-white/50 text-xs font-medium">Position your face within the frame</p>
          </div>
        </div>
      </div>

      <button onClick={() => setKycFormActive(false)} className="w-full bg-blue-600 text-white py-4 rounded-2xl font-bold text-lg shadow-xl shadow-blue-100 mt-6">
        Submit for Review
      </button>
    </div>
  );

  return (
    <div className="p-6 space-y-8">
      {kycFormActive && <KycForm />}
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-slate-900 text-white rounded-xl flex items-center justify-center">
            <Shield size={20} />
          </div>
          <h2 className="text-xl font-bold text-slate-900">Security Center</h2>
        </div>
        <button onClick={onClose} className="p-2 text-slate-400"><X /></button>
      </div>

      {/* KYC Status Card */}
      <div className={`p-6 rounded-[2rem] border-2 transition-all ${user.kycStatus === 'UNVERIFIED' ? 'bg-amber-50 border-amber-100' : 'bg-green-50 border-green-100'}`}>
        <div className="flex justify-between items-start mb-4">
          <div>
            <h3 className="font-bold text-slate-900">KYC Status</h3>
            <p className="text-xs text-slate-500 font-medium">Limit: ₦250,000 / day</p>
          </div>
          <div className={`px-3 py-1 rounded-full text-[10px] font-black tracking-wider ${user.kycStatus === 'UNVERIFIED' ? 'bg-amber-200 text-amber-800' : 'bg-green-200 text-green-800'}`}>
            {user.kycStatus}
          </div>
        </div>
        {user.kycStatus === 'UNVERIFIED' && (
          <button onClick={() => setKycFormActive(true)} className="w-full bg-amber-600 text-white py-3 rounded-xl font-bold text-sm shadow-lg shadow-amber-200">
            Complete Verification
          </button>
        )}
      </div>

      {/* Security Options */}
      <div className="space-y-4">
        <h3 className="text-sm font-bold text-slate-400 uppercase tracking-widest">Preferences</h3>
        <div className="bg-white rounded-[2rem] border border-slate-100 overflow-hidden">
          <SecurityItem icon={<Fingerprint />} label="Biometric Login" desc="Face ID / Touch ID" toggle active />
          <SecurityItem icon={<Lock />} label="Change Security PIN" desc="Last changed 3 months ago" />
          <SecurityItem icon={<Bell />} label="Push Notifications" desc="Alerts on all transactions" toggle active />
        </div>
      </div>

      {/* Recent Alerts */}
      <div className="space-y-4">
        <h3 className="text-sm font-bold text-slate-400 uppercase tracking-widest">Recent Activity</h3>
        <div className="space-y-3">
          {alerts.map(alert => (
            <div key={alert.id} className="p-4 bg-white border border-slate-100 rounded-2xl flex items-start gap-4">
              <div className={`p-2 rounded-xl ${alert.type === 'DANGER' ? 'bg-red-50 text-red-600' : 'bg-blue-50 text-blue-600'}`}>
                {alert.type === 'DANGER' ? <AlertTriangle size={20} /> : <Shield size={20} />}
              </div>
              <div>
                <h4 className="text-sm font-bold text-slate-800">{alert.title}</h4>
                <p className="text-xs text-slate-500 font-medium leading-relaxed">{alert.message}</p>
                <p className="text-[10px] text-slate-400 font-bold mt-2">{alert.timestamp.toLocaleTimeString()}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

const SecurityItem: React.FC<{ icon: React.ReactNode; label: string; desc: string; toggle?: boolean; active?: boolean }> = ({ icon, label, desc, toggle, active }) => (
  <div className="p-5 flex items-center justify-between border-b border-slate-50 last:border-0 hover:bg-slate-50/50 cursor-pointer">
    <div className="flex items-center gap-4">
      <div className="text-slate-400">{icon}</div>
      <div>
        <p className="text-sm font-bold text-slate-800">{label}</p>
        <p className="text-[10px] text-slate-400 font-bold uppercase">{desc}</p>
      </div>
    </div>
    {toggle ? (
      <div className={`w-10 h-5 rounded-full p-1 transition-colors ${active ? 'bg-blue-600' : 'bg-slate-200'}`}>
        <div className={`w-3 h-3 bg-white rounded-full transition-transform ${active ? 'translate-x-5' : ''}`}></div>
      </div>
    ) : <ChevronRight size={18} className="text-slate-300" />}
  </div>
);
