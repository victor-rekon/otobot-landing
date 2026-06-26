import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Youngpro Operations System',
  description: 'Inventory, production, task, and proof-of-work management system for Youngpro Cleaning Tools.',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
