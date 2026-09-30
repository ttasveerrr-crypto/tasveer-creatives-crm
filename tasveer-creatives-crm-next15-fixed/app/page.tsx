"use client";
import { useEffect } from "react"; import {useRouter} from "next/navigation"; import {supabaseBrowser} from "@/lib/supabase-browser";
export default function Home(){const r=useRouter();useEffect(()=>{supabaseBrowser().auth.getSession().then(({data})=>r.replace(data.session?"/dashboard":"/login"))},[r]);return <div className="page grid place-items-center">Loading Tasveer CRM…</div>}
