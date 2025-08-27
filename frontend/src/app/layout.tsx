import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { ThemeProvider } from "@/providers/theme-provider";
import { Web3Provider } from "@/providers/web3-provider";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

export const metadata: Metadata = {
  title: "re:Lease, stablecoin-powered jeonse platform",
  description: "Stablecoin-powered Jeonse Platform with Auto-Debt Conversion on Kaia blockchain",
  icons: {
    icon: '/logo-release-icon.png',
    shortcut: '/logo-release-icon.png',
    apple: '/logo-release-icon.png',
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${inter.variable} font-sans antialiased`}>
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
        >
          <Web3Provider>
            {children}
          </Web3Provider>
        </ThemeProvider>
        <div id="modal-root" />
      </body>
    </html>
  );
}
