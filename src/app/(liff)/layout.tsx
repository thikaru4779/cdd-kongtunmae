export default function LiffLayout({ children }: { children: React.ReactNode }) {
  return <div className="mx-auto flex w-full max-w-md flex-1 flex-col">{children}</div>;
}
