import { Blog } from "@/components/blog";
import { Docs } from "@/components/docs";
import { Download } from "@/components/download";
import { Features } from "@/components/features";
import { Footer } from "@/components/footer";
import { Header } from "@/components/header";
import { Hero } from "@/components/hero";
import { Pricing } from "@/components/pricing";
import { Showcase } from "@/components/showcase";

export default function Home() {
  return (
    <>
      <Header />
      <main className="pt-16">
        <Hero />
        <Showcase />
        <Features />
        <Pricing />
        <Blog />
        <Docs />
        <Download />
      </main>
      <Footer />
    </>
  );
}
