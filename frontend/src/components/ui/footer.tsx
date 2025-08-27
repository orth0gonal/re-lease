export function Footer() {
  return (
    <footer className="border-t border-border/10 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 mt-auto">
      <div className="container mx-auto px-4 py-6">
        <div className="flex flex-col md:flex-row justify-between items-center space-y-4 md:space-y-0">
          <span className="text-sm text-muted-foreground">
            Powered by re:Lease
          </span>
          <p className="text-sm text-muted-foreground">
            © 2025 re:Lease. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
  )
}