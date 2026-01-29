
import React, { useState, useRef, useEffect } from 'react';
import { Smartphone, Mail, ArrowRight, Fingerprint, ShieldCheck, CheckCircle, ChevronLeft, AlertCircle, Loader2 } from 'lucide-react';
import { PrimaryButton } from '../components/Widgets';

interface AuthProps {
  onLogin: () => void;
}

const MOCK_DB = {
  getAccount: (identifier: string) => {
    const data = localStorage.getItem(`user_${identifier}`);
    return data ? JSON.parse(data) : null;
  },
  saveAccount: (identifier: string, pin: string) => {
    localStorage.setItem(`user_${identifier}`, JSON.stringify({ identifier, pin }));
    const users = JSON.parse(localStorage.getItem('registered_users') || '[]');
    if (!users.includes(identifier)) {
      users.push(identifier);
      localStorage.setItem('registered_users', JSON.stringify(users));
    }
  }
};

type AuthStep = 
  | 'WELCOME' 
  | 'LOGIN_REGISTER' 
  | 'LOGIN_PIN' 
  | 'OTP' 
  | 'CREATE_PIN' 
  | 'CONFIRM_PIN' 
  | 'BIOMETRICS' 
  | 'FORGOT_PIN' 
  | 'RESET_OTP' 
  | 'RESET_CREATE_PIN' 
  | 'RESET_CONFIRM_PIN' 
  | 'RESET_SUCCESS';

/**
 * PinCodeField: A highly accessible and performant PIN input component.
 * Uses a single hidden input to manage focus and keyboard state.
 */
const PinCodeField: React.FC<{
  length: number;
  value: string;
  onChange: (val: string) => void;
  onComplete: (val: string) => void;
  isPassword?: boolean;
  error?: boolean;
  disabled?: boolean;
  autoFocus?: boolean;
}> = ({ length, value, onChange, onComplete, isPassword = true, error = false, disabled = false, autoFocus = true }) => {
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (autoFocus) {
      const timer = setTimeout(() => inputRef.current?.focus(), 150);
      return () => clearTimeout(timer);
    }
  }, [autoFocus]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value.replace(/[^0-9]/g, '').slice(0, length);
    onChange(val);
    if (val.length === length) {
      onComplete(val);
    }
  };

  return (
    <div className="relative w-full max-w-xs mx-auto" onClick={() => inputRef.current?.focus()}>
      {/* Hidden input to handle focus and keyboard */}
      <input
        ref={inputRef}
        type="tel"
        inputMode="numeric"
        value={value}
        onChange={handleInputChange}
        disabled={disabled}
        className="absolute inset-0 opacity-0 cursor-default"
        autoComplete="one-time-code"
      />
      
      {/* Visual boxes */}
      <div className="flex justify-between gap-3 pointer-events-none">
        {Array.from({ length }).map((_, i) => {
          const isFocused = value.length === i;
          const char = value[i] || '';
          return (
            <div
              key={i}
              className={`w-full aspect-square bg-white border-2 rounded-2xl flex items-center justify-center text-3xl font-bold transition-all
                ${error ? 'border-red-500 bg-red-50 ring-4 ring-red-500/5' : isFocused ? 'border-blue-950 ring-4 ring-blue-950/5' : 'border-slate-200'}
                ${char ? 'text-slate-800' : 'text-slate-300'}
              `}
            >
              {isPassword && char ? '•' : char}
              {isFocused && !disabled && (
                <div className="absolute w-0.5 h-8 bg-blue-950 animate-pulse" />
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};

export const Auth: React.FC<AuthProps> = ({ onLogin }) => {
  const [step, setStep] = useState<AuthStep>('WELCOME');
  const [identifier, setIdentifier] = useState('');
  const [isRegistering, setIsRegistering] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [resendTimer, setResendTimer] = useState(30);
  
  const [pinValue, setPinValue] = useState('');
  const [confirmPinValue, setConfirmPinValue] = useState('');
  const [otpValue, setOtpValue] = useState('');
  const [tempSavedPin, setTempSavedPin] = useState('');
  const [pinError, setPinError] = useState(false);

  const loginInputRef = useRef<HTMLInputElement>(null);
  const forgotInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (step === 'LOGIN_REGISTER' && loginInputRef.current) {
      setTimeout(() => loginInputRef.current?.focus(), 150);
    }
    if (step === 'FORGOT_PIN' && forgotInputRef.current) {
      setTimeout(() => forgotInputRef.current?.focus(), 150);
    }
    // Reset specific input values when moving between core phases
    if (step === 'CREATE_PIN') setPinValue('');
    if (step === 'CONFIRM_PIN') setConfirmPinValue('');
    if (step === 'LOGIN_PIN') setPinValue('');
    if (step === 'OTP' || step === 'RESET_OTP') setOtpValue('');
  }, [step]);

  useEffect(() => {
    let interval: any;
    if (resendTimer > 0 && ['RESET_OTP', 'OTP'].includes(step)) {
      interval = setInterval(() => setResendTimer(prev => prev - 1), 1000);
    }
    return () => clearInterval(interval);
  }, [resendTimer, step]);

  const handleIdentifierSubmit = async () => {
    setLoading(true);
    setError(null);
    await new Promise(r => setTimeout(r, 800));
    const account = MOCK_DB.getAccount(identifier);
    
    if (isRegistering) {
      if (account) setError('Account already exists. Please sign in.');
      else setStep('OTP');
    } else {
      if (account) setStep('LOGIN_PIN');
      else setError('Account not found. Please create an account.');
    }
    setLoading(false);
  };

  const handleForgotIdentifierSubmit = async () => {
    setLoading(true);
    setError(null);
    await new Promise(r => setTimeout(r, 800));
    if (MOCK_DB.getAccount(identifier)) setStep('RESET_OTP');
    else setError('Account not found. Please create an account.');
    setLoading(false);
  };

  const handleLoginPinComplete = async (val: string) => {
    setLoading(true);
    setPinError(false);
    await new Promise(r => setTimeout(r, 600));
    const account = MOCK_DB.getAccount(identifier);
    if (account && account.pin === val) {
      onLogin();
    } else {
      setPinError(true);
      setPinValue('');
    }
    setLoading(false);
  };

  const handleCreatePinComplete = (val: string) => {
    setTempSavedPin(val);
    setStep('CONFIRM_PIN');
  };

  const handleConfirmPinComplete = (val: string) => {
    if (val === tempSavedPin) {
      MOCK_DB.saveAccount(identifier, val);
      setPinError(false);
      setStep('BIOMETRICS');
    } else {
      setPinError(true);
      setConfirmPinValue('');
    }
  };

  const handleResetConfirmComplete = (val: string) => {
    if (val === tempSavedPin) {
      MOCK_DB.saveAccount(identifier, val);
      setPinError(false);
      setStep('RESET_SUCCESS');
    } else {
      setPinError(true);
      setConfirmPinValue('');
    }
  };

  const StepWrapper: React.FC<{ children: React.ReactNode; onBack?: () => void }> = ({ children, onBack }) => (
    <div className="fixed inset-0 bg-white z-[60] flex flex-col p-8 overflow-y-auto" role="dialog" aria-modal="true">
      {onBack && (
        <button onClick={onBack} className="self-start mb-6 p-2 -ml-2 text-slate-400 hover:text-slate-600 transition-colors" aria-label="Go back">
          <ChevronLeft />
        </button>
      )}
      {children}
    </div>
  );

  if (step === 'WELCOME') {
    return (
      <div className="fixed inset-0 bg-white z-[60] flex flex-col p-8">
        <div className="flex-1 flex flex-col justify-center items-center text-center space-y-8">
          <div className="w-24 h-24 bg-blue-950 rounded-[2rem] flex items-center justify-center text-white shadow-2xl shadow-black/10 rotate-6 transform hover:rotate-0 transition-transform duration-500">
            <Smartphone size={48} />
          </div>
          <div className="space-y-3">
            <h1 className="text-5xl font-black text-slate-900 tracking-tight">TAPPAY</h1>
            <p className="text-slate-500 text-lg font-medium px-4 leading-relaxed text-balance">
              Experience the future of <span className="text-blue-950 font-bold">contactless payments</span>.
            </p>
          </div>
        </div>
        <div className="space-y-4">
          <PrimaryButton label="Sign In" onClick={() => { setIsRegistering(false); setStep('LOGIN_REGISTER'); setError(null); }} />
          <button onClick={() => { setIsRegistering(true); setStep('LOGIN_REGISTER'); setError(null); }} className="w-full bg-white text-slate-900 border-2 border-slate-100 py-5 rounded-2xl font-bold text-lg active:scale-95 transition-all">
            Create New Account
          </button>
        </div>
      </div>
    );
  }

  if (step === 'LOGIN_REGISTER') {
    return (
      <StepWrapper onBack={() => setStep('WELCOME')}>
        <div className="space-y-2 mb-12">
          <h2 className="text-3xl font-bold text-slate-900">{isRegistering ? 'Join TAPPAY' : 'Welcome Back'}</h2>
          <p className="text-slate-500 font-medium">{isRegistering ? 'Start your journey today' : 'Sign in to access your wallet'}</p>
        </div>
        <div className="space-y-6 flex-1">
          <div className="space-y-2">
            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest px-1">Phone or Email</label>
            <div className={`flex items-center gap-3 bg-white px-4 py-4 rounded-2xl border transition-colors cursor-text ${error ? 'border-red-500 ring-4 ring-red-500/5' : 'border-slate-200 focus-within:border-blue-950'}`} onClick={() => loginInputRef.current?.focus()}>
              <Mail className={error ? 'text-red-400' : 'text-slate-400'} size={20} />
              <input ref={loginInputRef} type="text" value={identifier} onChange={(e) => { setIdentifier(e.target.value); setError(null); }} placeholder="name@example.com" autoFocus className="bg-transparent outline-none flex-1 text-slate-800 font-medium text-base" />
            </div>
            {error && <div className="flex items-center gap-2 text-red-600 px-1 mt-2 animate-shake"><AlertCircle size={14} /><p className="text-xs font-bold">{error}</p></div>}
          </div>
          <div className="flex-1" />
          {!isRegistering && (
            <button onClick={() => { setStep('FORGOT_PIN'); setError(null); }} className="w-full text-center text-blue-950 font-bold text-sm mb-4 py-2">
              Forgot Security PIN?
            </button>
          )}
          <PrimaryButton label="Continue" onClick={handleIdentifierSubmit} loading={loading} disabled={!identifier} icon={<ArrowRight size={20} />} />
        </div>
      </StepWrapper>
    );
  }

  if (step === 'LOGIN_PIN') {
    return (
      <StepWrapper onBack={() => setStep('LOGIN_REGISTER')}>
        <div className="space-y-2 mb-12">
          <h2 className="text-3xl font-bold text-slate-900">Security PIN</h2>
          <p className="text-slate-500 font-medium text-balance">Enter your 4-digit PIN for <span className="text-slate-900 font-bold">{identifier}</span></p>
        </div>
        <div className="flex-1 space-y-8">
          <PinCodeField length={4} value={pinValue} onChange={setPinValue} onComplete={handleLoginPinComplete} error={pinError} disabled={loading} />
          {pinError && <div className="text-center text-red-600 font-bold text-sm animate-shake">Incorrect PIN. Try again.</div>}
          <div className="text-center">
            <button onClick={() => { setStep('FORGOT_PIN'); setError(null); }} className="text-blue-950 font-bold text-sm">Forgot PIN?</button>
          </div>
          {loading && <div className="flex flex-col items-center gap-2 text-blue-950"><Loader2 className="animate-spin" /><p className="text-[10px] font-black uppercase tracking-widest">Verifying</p></div>}
        </div>
      </StepWrapper>
    );
  }

  if (step === 'FORGOT_PIN') {
    return (
      <StepWrapper onBack={() => setStep('LOGIN_REGISTER')}>
        <div className="space-y-2 mb-12"><h2 className="text-3xl font-bold text-slate-900">Forgot PIN</h2><p className="text-slate-500 font-medium">Enter your registered email or phone number to reset your security PIN.</p></div>
        <div className="space-y-6 flex-1">
          <div className="space-y-2">
            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest px-1">Account ID</label>
            <div className={`flex items-center gap-3 bg-white px-4 py-4 rounded-2xl border transition-colors cursor-text ${error ? 'border-red-500 ring-4 ring-red-500/5' : 'border-slate-200 focus-within:border-blue-950'}`} onClick={() => forgotInputRef.current?.focus()}>
              <Smartphone className={error ? 'text-red-400' : 'text-slate-400'} size={20} />
              <input ref={forgotInputRef} type="text" placeholder="Enter email or phone" value={identifier} onChange={(e) => { setIdentifier(e.target.value); setError(null); }} autoFocus className="bg-transparent outline-none flex-1 text-slate-800 font-medium text-base" />
            </div>
            {error && <div className="flex items-center gap-2 text-red-600 px-1 mt-2 animate-shake"><AlertCircle size={14} /><p className="text-xs font-bold">{error}</p></div>}
          </div>
          <div className="flex-1" />
          <PrimaryButton label="Continue" onClick={handleForgotIdentifierSubmit} loading={loading} disabled={!identifier} />
        </div>
      </StepWrapper>
    );
  }

  if (['OTP', 'RESET_OTP'].includes(step)) {
    const isReset = step === 'RESET_OTP';
    return (
      <StepWrapper onBack={() => setStep(isReset ? 'FORGOT_PIN' : 'LOGIN_REGISTER')}>
        <div className="space-y-2 mb-12">
          <h2 className="text-3xl font-bold text-slate-900">{isReset ? 'Security Verification' : 'Verify Identity'}</h2>
          <p className="text-slate-500 font-medium">Code sent to: <span className="text-slate-900 font-bold">{identifier}</span></p>
        </div>
        <div className="flex-1 space-y-12">
          <PinCodeField length={isReset ? 6 : 4} isPassword={false} value={otpValue} onChange={setOtpValue} onComplete={() => {}} />
          <div className="text-center">
            <p className="text-sm font-medium text-slate-400">
              Didn't receive it? {resendTimer > 0 ? (
                <span className="text-blue-950 font-bold ml-1">Wait {resendTimer}s</span>
              ) : (
                <button onClick={() => setResendTimer(30)} className="text-blue-950 font-bold hover:underline ml-1">Resend Code</button>
              )}
            </p>
          </div>
          <PrimaryButton label="Verify & Continue" disabled={otpValue.length !== (isReset ? 6 : 4)} onClick={() => setStep(isReset ? 'RESET_CREATE_PIN' : 'CREATE_PIN')} />
        </div>
      </StepWrapper>
    );
  }

  if (['CREATE_PIN', 'CONFIRM_PIN', 'RESET_CREATE_PIN', 'RESET_CONFIRM_PIN'].includes(step)) {
    const isConfirm = ['CONFIRM_PIN', 'RESET_CONFIRM_PIN'].includes(step);
    const isReset = ['RESET_CREATE_PIN', 'RESET_CONFIRM_PIN'].includes(step);
    const value = isConfirm ? confirmPinValue : pinValue;
    const setValue = isConfirm ? setConfirmPinValue : setPinValue;
    const onComp = isConfirm ? (isReset ? handleResetConfirmComplete : handleConfirmPinComplete) : (val: string) => { setTempSavedPin(val); setStep(isReset ? 'RESET_CONFIRM_PIN' : 'CONFIRM_PIN'); };

    return (
      <StepWrapper onBack={() => setStep(isConfirm ? (isReset ? 'RESET_CREATE_PIN' : 'CREATE_PIN') : (isReset ? 'RESET_OTP' : 'OTP'))}>
        <div className="space-y-2 mb-12">
          <h2 className="text-3xl font-bold text-slate-900">{isConfirm ? 'Confirm Security PIN' : 'Create Security PIN'}</h2>
          <p className="text-slate-500 font-medium">{isConfirm ? 'Enter the 4-digit PIN again to confirm.' : 'Set a 4-digit PIN for secure transactions.'}</p>
        </div>
        <div className="flex-1 space-y-8">
          <PinCodeField length={4} value={value} onChange={setValue} onComplete={onComp} error={pinError && isConfirm} />
          {pinError && isConfirm && <div className="text-center text-red-600 font-bold text-sm animate-shake">PINs do not match. Please try again.</div>}
          <div className="flex-1" />
          <div className="w-full p-6 bg-slate-50 rounded-3xl border border-slate-100 flex items-start gap-4 mb-8">
            <ShieldCheck className="text-blue-900 shrink-0" size={24} />
            <p className="text-xs text-slate-500 leading-relaxed">Your PIN is encrypted and stored locally. Never share your PIN with anyone.</p>
          </div>
        </div>
      </StepWrapper>
    );
  }

  if (step === 'RESET_SUCCESS') {
    return (
      <div className="fixed inset-0 bg-white z-[90] p-8 flex flex-col items-center justify-center text-center">
        <div className="w-24 h-24 bg-green-50 text-green-600 rounded-full flex items-center justify-center mb-8"><CheckCircle size={60} /></div>
        <h2 className="text-3xl font-black text-slate-900 mb-4">Reset Successful</h2>
        <p className="text-slate-500 font-medium mb-12">Your security PIN has been updated. Please log in with your new credentials.</p>
        <PrimaryButton label="Go to Login" onClick={() => { setStep('LOGIN_REGISTER'); setIsRegistering(false); }} />
      </div>
    );
  }

  if (step === 'BIOMETRICS') {
    return (
      <div className="fixed inset-0 bg-white z-[60] p-8 flex flex-col items-center justify-center text-center space-y-12">
        <div className="w-32 h-32 bg-blue-50 text-blue-950 rounded-full flex items-center justify-center animate-pulse"><Fingerprint size={80} /></div>
        <div className="space-y-2">
          <h2 className="text-3xl font-bold text-slate-900">Biometric Access</h2>
          <p className="text-slate-500 font-medium max-w-xs mx-auto">Use Face ID or Touch ID for effortless login and authorization.</p>
        </div>
        <div className="w-full space-y-4">
          <PrimaryButton label="Enable Biometrics" onClick={onLogin} icon={<ShieldCheck size={20} />} />
          <button onClick={onLogin} className="text-slate-400 font-bold text-sm uppercase tracking-widest py-2">Maybe Later</button>
        </div>
      </div>
    );
  }

  return null;
};
