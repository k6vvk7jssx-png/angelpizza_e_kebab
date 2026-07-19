import type { Metadata } from "next";
import { Outfit, Montserrat, Playball } from "next/font/google";
import "./globals.css";

const outfit = Outfit({
  variable: "--font-outfit",
  subsets: ["latin"],
});

const montserrat = Montserrat({
  variable: "--font-montserrat",
  subsets: ["latin"],
});

const playball = Playball({
  weight: "400",
  variable: "--font-playball",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Angels Livorno | Pizza, Kebab & Fast Food",
  description: "Ordina le migliori specialità di Angels Livorno in tempo reale. Consegna a domicilio e asporto a Piazza Mazzini 82/83.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="it"
      className={`${outfit.variable} ${montserrat.variable} ${playball.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
