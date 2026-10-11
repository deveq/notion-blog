import { Separator } from "@/components/ui/separator"
import { SITE_CONFIG } from "@/constants/site"

export function Footer() {
  const year = new Date().getFullYear()

  return (
    <>
      <Separator />
      <footer className="bg-background py-6 text-center text-sm text-muted-foreground">
        <p>
          &copy; {year} {SITE_CONFIG.name}. All rights reserved.
        </p>
      </footer>
    </>
  )
}
