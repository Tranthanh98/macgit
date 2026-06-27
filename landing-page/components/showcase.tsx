"use client";

import Image from "next/image";

export function Showcase() {
  return (
    <section className="py-24 px-6 bg-secondary/30">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-16">
          <div className="inline-block px-4 py-2 rounded-full bg-primary/10 mb-4">
            <span className="text-sm font-semibold text-primary">
              See It In Action
            </span>
          </div>
          <h2 className="text-4xl md:text-5xl font-bold tracking-tight mb-4 text-balance">
            Beautiful, Native Interface
          </h2>
          <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
            Experience the power of Git management with an interface designed
            specifically for macOS.
          </p>
        </div>

        <Image
          src="/screenshot.png"
          alt="Commit+ Application Interface"
          width={1440}
          height={900}
          className="w-full h-auto shadow-2xl rounded-lg"
          priority
        />
      </div>
    </section>
  );
}
