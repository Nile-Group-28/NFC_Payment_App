
export type UserRole = 'CONSUMER' | 'MERCHANT' | 'ADMIN';

export type TransactionType = 'PAYMENT' | 'TOP_UP' | 'TRANSFER' | 'RECEIVE' | 'WITHDRAW';
export type TransactionStatus = 'SUCCESS' | 'PENDING' | 'FAILED';
export type TransactionCategory = 'FOOD' | 'TRANSPORT' | 'SHOPPING' | 'UTILITIES' | 'SUBSCRIPTION' | 'OTHER';

export interface Transaction {
  id: string;
  type: TransactionType;
  amount: number;
  currency: string;
  status: TransactionStatus;
  timestamp: Date;
  description: string;
  recipient?: string;
  sender?: string;
  category: TransactionCategory;
}

export interface UserProfile {
  id: string;
  name: string;
  email: string;
  phone: string;
  balance: number;
  role: UserRole;
  kycStatus: 'UNVERIFIED' | 'PENDING' | 'VERIFIED_L1' | 'VERIFIED_L2' | 'VERIFIED_L3';
  isBiometricsEnabled: boolean;
  pinCreated: boolean;
}

export interface Alert {
  id: string;
  title: string;
  message: string;
  type: 'INFO' | 'WARNING' | 'DANGER';
  timestamp: Date;
}
