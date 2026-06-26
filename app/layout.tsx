import type { Metadata } from 'next';
import { Syne, Inter } from 'next/font/google';
import './globals.css';

const syne = Syne({
  subsets: ['latin'],
  weight: ['700', '800'],
  variable: '--font-syne',
  display: 'swap',
});

const inter = Inter({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  variable: '--font-inter',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'Youngpro Operations System',
  description: 'Inventory, production, task, and proof-of-work management system for Youngpro Cleaning Tools.',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="id" className={`${syne.variable} ${inter.variable}`}>
      <body>{children}</body>
    </html>
  );
}
