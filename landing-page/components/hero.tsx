import { ArrowRight } from "lucide-react";
import Image from "next/image";
import Link from "next/link";

export function Hero() {
  return (
    <section className="pt-32 pb-24 px-6">
      <div className="max-w-[1440px] mx-auto grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
        <div className="text-center lg:text-left">
          <div className="inline-block mb-6 px-4 py-2 bg-secondary rounded-full">
            <p className="text-sm font-medium text-secondary-foreground">
              Native. Lightweight. Open Source.
            </p>
          </div>

          <h1 className="text-5xl md:text-7xl font-bold tracking-tight mb-6 leading-tight">
            The Git client <br />
            <span className="text-primary">macOS deserves</span>
          </h1>

          <p className="text-xl text-muted-foreground mb-8 max-w-2xl mx-auto lg:mx-0 leading-relaxed">
            Commit+ is a fast, native Git client built with Swift and SwiftUI.
            Zero external dependencies. Drag and drop. Undo any action. Free and
            open source.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start mb-8">
            <Link
              href="#download"
              className="bg-primary text-primary-foreground px-8 py-4 rounded-2xl font-semibold hover:opacity-90 transition inline-flex items-center justify-center gap-2 group"
            >
              Download for Free
              <ArrowRight
                size={20}
                className="group-hover:translate-x-1 transition"
              />
            </Link>

            <Link
              href="#features"
              className="border border-border bg-card text-foreground px-8 py-4 rounded-2xl font-semibold hover:bg-secondary transition"
            >
              View Features
            </Link>
          </div>

          <p className="text-sm text-muted-foreground">
            macOS 26.2+ • Swift • SwiftUI • No dependencies
          </p>
        </div>

        <div className="relative">
          <div className="inline-block px-4 py-2 rounded-full bg-primary/10 mb-4 ml-1">
            <span className="text-sm font-semibold text-primary">
              See It In Action
            </span>
          </div>
          <Image
            src="/welcome.png"
            alt="Commit+ Application Interface"
            width={1440}
            height={900}
            className="w-full h-auto shadow-2xl rounded-lg"
            priority
          />
        </div>
      </div>
    </section>
  );
}
