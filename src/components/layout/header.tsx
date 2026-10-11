import Link from "next/link"
import { SITE_CONFIG } from "@/constants/site"
import { ThemeToggle } from "@/components/theme/theme-toggle"
import { Nav } from "@/components/layout/nav"
import { MobileNav } from "@/components/layout/mobile-nav"
import { Separator } from "@/components/ui/separator"

export function Header() {
  return (
    <>
      <header className="sticky top-0 z-50 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="flex h-14 items-center justify-between px-4 sm:px-6 lg:px-8">
          <div className="flex items-center">
            <Link href="/" className="text-lg font-semibold">
              {SITE_CONFIG.name}
            </Link>
          </div>
          <Nav className="hidden md:flex" />
          <div className="flex items-center gap-2">
            <ThemeToggle />
            <MobileNav className="md:hidden" />
          </div>
        </div>
      </header>
      <Separator />
    </>
  )
}
