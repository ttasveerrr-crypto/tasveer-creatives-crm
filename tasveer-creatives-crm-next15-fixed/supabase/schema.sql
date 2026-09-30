create extension if not exists pgcrypto;
create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade, full_name text not null default '', role text not null default 'owner' check(role in ('owner','admin','member')), created_at timestamptz default now());
create table if not exists public.company_settings(id int primary key default 1, company_name text not null default 'Tasveer Creatives', legal_name text, email text, phone text, address text, gstin text, website text, logo_url text, signature_url text, bank_details text, default_terms text default 'Payment is due by the stated due date. Ad spend and third-party charges are separate unless explicitly included.', updated_at timestamptz default now());
create table if not exists public.team_members(id uuid primary key default gen_random_uuid(), user_id uuid unique references auth.users(id) on delete cascade, full_name text not null, role text not null default 'member', permissions jsonb not null default '{}'::jsonb, active boolean default true, created_at timestamptz default now());
create table if not exists public.clients(id uuid primary key default gen_random_uuid(), name text not null, business_name text not null, email text, phone text, address text, gstin text, logo_url text, notes text, created_at timestamptz default now(), updated_at timestamptz default now());
create table if not exists public.services(id uuid primary key default gen_random_uuid(), name text not null, description text, default_price numeric(12,2) not null default 0, active boolean default true, created_at timestamptz default now());
create table if not exists public.invoices(id uuid primary key default gen_random_uuid(), invoice_number text unique not null, client_id uuid not null references public.clients(id), issue_date date not null default current_date, due_date date not null, status text not null default 'draft' check(status in ('draft','sent','partially_paid','paid','overdue','cancelled')), subtotal numeric(12,2) not null default 0, discount numeric(12,2) not null default 0, tax numeric(12,2) not null default 0, total numeric(12,2) not null default 0, amount_paid numeric(12,2) not null default 0, notes text, terms text, created_by uuid references auth.users(id), created_at timestamptz default now(), updated_at timestamptz default now());
create table if not exists public.invoice_items(id uuid primary key default gen_random_uuid(), invoice_id uuid not null references public.invoices(id) on delete cascade, service_id uuid references public.services(id), name text not null, description text, quantity numeric(12,2) not null default 1, rate numeric(12,2) not null default 0, discount numeric(12,2) not null default 0, tax_rate numeric(5,2) not null default 0, amount numeric(12,2) not null default 0, sort_order int not null default 0);
create table if not exists public.payments(id uuid primary key default gen_random_uuid(), client_id uuid references public.clients(id), invoice_id uuid references public.invoices(id), amount numeric(12,2) not null, payment_date date not null default current_date, method text, reference text, notes text, screenshot_url text, created_by uuid references auth.users(id), created_at timestamptz default now());
create table if not exists public.recurring_schedules(id uuid primary key default gen_random_uuid(), client_id uuid not null references public.clients(id), name text not null, total_amount numeric(12,2) not null default 0, frequency text not null default 'monthly', active boolean not null default true, start_date date not null, next_due_date date not null, terms text, created_at timestamptz default now());
create table if not exists public.recurring_payments(id uuid primary key default gen_random_uuid(), schedule_id uuid not null references public.recurring_schedules(id) on delete cascade, label text not null, amount numeric(12,2) not null, due_date date not null, invoice_id uuid references public.invoices(id), status text not null default 'upcoming' check(status in ('upcoming','due','paid','overdue')), position int not null default 1);
create table if not exists public.quotations(id uuid primary key default gen_random_uuid(), quotation_number text unique not null, client_id uuid not null references public.clients(id), issue_date date default current_date, valid_until date, status text default 'draft', content jsonb not null default '{}'::jsonb, created_by uuid references auth.users(id), created_at timestamptz default now());
create table if not exists public.proposals(id uuid primary key default gen_random_uuid(), proposal_number text unique not null, client_id uuid not null references public.clients(id), issue_date date default current_date, status text default 'draft', content jsonb not null default '{}'::jsonb, created_by uuid references auth.users(id), created_at timestamptz default now());
create table if not exists public.agreements(id uuid primary key default gen_random_uuid(), agreement_number text unique not null, client_id uuid not null references public.clients(id), start_date date, end_date date, status text default 'draft', content jsonb not null default '{}'::jsonb, created_by uuid references auth.users(id), created_at timestamptz default now());
create table if not exists public.document_templates(id uuid primary key default gen_random_uuid(), type text unique not null, name text not null, body text not null, updated_at timestamptz default now());
create table if not exists public.whatsapp_templates(id uuid primary key default gen_random_uuid(), name text not null, type text not null, body text not null, active boolean default true, updated_at timestamptz default now());
create table if not exists public.expenses(id uuid primary key default gen_random_uuid(), category text not null, amount numeric(12,2) not null, expense_date date not null default current_date, description text, created_by uuid references auth.users(id), created_at timestamptz default now());
create table if not exists public.activity_logs(id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id), action text not null, entity_type text, entity_id uuid, metadata jsonb default '{}'::jsonb, created_at timestamptz default now());


create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$ declare r text; begin if not exists(select 1 from profiles) then r:='owner'; else r:='member'; end if; insert into profiles(id,full_name,role) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),r) on conflict(id) do nothing; return new; end; $$;
drop trigger if exists on_auth_user_created on auth.users; create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.bootstrap_owner(p_full_name text) returns void language plpgsql security definer set search_path=public as $$ begin if exists(select 1 from profiles) then raise exception 'Owner setup already completed'; end if; insert into profiles(id,full_name,role) values(auth.uid(),coalesce(p_full_name,''),'owner'); insert into company_settings(id) values(1) on conflict do nothing; insert into document_templates(type,name,body) values
('invoice','Invoice','Payment is due by {{due_date}}. Please make the payment and share the payment screenshot once completed.

{{company_terms}}'),
('quotation','Quotation','This quotation is valid until {{valid_until}}. Services, pricing and scope are subject to the agreed terms.'),
('proposal','Proposal','We propose the following creative advertising scope for {{business_name}}.

Services: {{services}}
Investment: {{total}}'),
('agreement','Master Agreement','1. PARTIES & EFFECTIVE DATE
This Agreement is between Tasveer Creatives and {{business_name}}, effective {{start_date}}.

2. SCOPE OF SERVICES
{{services}}

3. DELIVERABLES
{{deliverables}}

4. FEES & PAYMENT TERMS
Monthly fee: {{monthly_fee}}. Payment schedule: {{payment_terms}}.

5. ADVERTISING BUDGET & THIRD-PARTY COSTS
Advertising spend and third-party charges are separate unless expressly included.

6. CLIENT RESPONSIBILITIES
Client will provide timely access, information, approvals and assets.

7. APPROVALS & REVISIONS
Timelines depend on timely approvals. Revision limits follow the agreed scope.

8. PERFORMANCE DISCLAIMER
No specific leads, sales, reach, followers, ROAS or revenue are guaranteed. Platform, market, creative, budget and client-side factors affect results.

9. INTELLECTUAL PROPERTY
Ownership and usage rights follow the agreed commercial terms.

10. CONFIDENTIALITY
Both parties will keep confidential business information private.

11. PAYMENT DELAYS & SUSPENSION
Services may be paused for overdue payments.

12. CANCELLATION & TERMINATION
Notice period: {{notice_period}}.

13. REFUNDS
Refunds, if any, follow the agreed commercial terms.

14. LIMITATION OF LIABILITY
Liability is limited to the extent permitted by applicable law.

15. GOVERNING LAW & DISPUTES
Applicable jurisdiction: {{jurisdiction}}.

16. ENTIRE AGREEMENT
This document and its agreed schedules form the complete agreement.'),
('receipt','Payment Receipt','Payment of {{amount}} received against Invoice {{invoice_number}} on {{payment_date}}. Thank you.');
insert into whatsapp_templates(name,type,body) values
('Payment Due','payment_due','Hi {{client_name}}, just a reminder that ₹{{amount}} against Invoice {{invoice_number}} is due on {{due_date}}. Please make the payment and send the payment screenshot here once done. Thank you, Tasveer Creatives.'),
('Overdue Payment','overdue','Hi {{client_name}}, a quick reminder that ₹{{amount}} against Invoice {{invoice_number}} is overdue. Please complete the payment and share the payment screenshot here once done. Thank you, Tasveer Creatives.'),
('Invoice Sent','invoice_sent','Hi {{client_name}}, sharing Invoice {{invoice_number}} for ₹{{amount}}. Due date: {{due_date}}. Please let me know if you need anything from my side.'); end; $$;

create or replace function public.next_doc_number(prefix text) returns text language plpgsql security definer set search_path=public as $$ declare y text:=to_char(current_date,'YYYY'); n int; outv text; begin if prefix='TC' then select count(*)+1 into n from invoices where invoice_number like 'TC-'||y||'-%'; elsif prefix='QT' then select count(*)+1 into n from quotations where quotation_number like 'QT-'||y||'-%'; elsif prefix='PR' then select count(*)+1 into n from proposals where proposal_number like 'PR-'||y||'-%'; else select count(*)+1 into n from agreements where agreement_number like 'AGR-'||y||'-%'; end if; outv:=prefix||'-'||y||'-'||lpad(n::text,3,'0'); return outv; end; $$;

create or replace function public.create_invoice(p_client_id uuid,p_issue_date date,p_due_date date,p_notes text,p_terms text,p_items jsonb) returns uuid language plpgsql security definer set search_path=public as $$ declare inv_id uuid:=gen_random_uuid(); num text; x jsonb; sub numeric:=0; disc numeric:=0; tx numeric:=0; base numeric; amt numeric; i int:=0; begin if not exists(select 1 from profiles where id=auth.uid()) then raise exception 'Unauthorized'; end if; num:=next_doc_number('TC'); for x in select * from jsonb_array_elements(p_items) loop base:=coalesce((x->>'quantity')::numeric,0)*coalesce((x->>'rate')::numeric,0); disc:=disc+coalesce((x->>'discount')::numeric,0); tx:=tx+(greatest(0,base-coalesce((x->>'discount')::numeric,0))*coalesce((x->>'tax_rate')::numeric,0)/100); amt:=greatest(0,base-coalesce((x->>'discount')::numeric,0))+greatest(0,base-coalesce((x->>'discount')::numeric,0))*coalesce((x->>'tax_rate')::numeric,0)/100; sub:=sub+base; insert into invoice_items(invoice_id,service_id,name,description,quantity,rate,discount,tax_rate,amount,sort_order) values(inv_id,nullif(x->>'service_id','')::uuid,x->>'name',x->>'description',coalesce((x->>'quantity')::numeric,1),coalesce((x->>'rate')::numeric,0),coalesce((x->>'discount')::numeric,0),coalesce((x->>'tax_rate')::numeric,0),amt,i); i:=i+1; end loop; insert into invoices(id,invoice_number,client_id,issue_date,due_date,status,subtotal,discount,tax,total,notes,terms,created_by) values(inv_id,num,p_client_id,p_issue_date,p_due_date,'draft',sub,disc,tx,sub-disc+tx,p_notes,p_terms,auth.uid()); insert into activity_logs(user_id,action,entity_type,entity_id) values(auth.uid(),'created','invoice',inv_id); return inv_id; end; $$;

create or replace function public.record_payment(p_client uuid,p_invoice uuid,p_amount numeric,p_date date,p_method text,p_reference text,p_notes text) returns uuid language plpgsql security definer set search_path=public as $$ declare pid uuid:=gen_random_uuid(); total numeric; paid numeric; newpaid numeric; begin if not exists(select 1 from profiles where id=auth.uid()) then raise exception 'Unauthorized'; end if; select total,amount_paid into total,paid from invoices where id=p_invoice for update; newpaid:=paid+p_amount; insert into payments(id,client_id,invoice_id,amount,payment_date,method,reference,notes,created_by) values(pid,p_client,p_invoice,p_amount,p_date,p_method,p_reference,p_notes,auth.uid()); update invoices set amount_paid=newpaid,status=case when newpaid>=total then 'paid' when newpaid>0 then 'partially_paid' when due_date<current_date then 'overdue' else status end,updated_at=now() where id=p_invoice; insert into activity_logs(user_id,action,entity_type,entity_id,metadata) values(auth.uid(),'payment_received','payment',pid,jsonb_build_object('amount',p_amount)); return pid; end; $$;

alter table profiles enable row level security; alter table company_settings enable row level security; alter table team_members enable row level security; alter table clients enable row level security; alter table services enable row level security; alter table invoices enable row level security; alter table invoice_items enable row level security; alter table payments enable row level security; alter table recurring_schedules enable row level security; alter table recurring_payments enable row level security; alter table quotations enable row level security; alter table proposals enable row level security; alter table agreements enable row level security; alter table document_templates enable row level security; alter table whatsapp_templates enable row level security; alter table expenses enable row level security; alter table activity_logs enable row level security;

do $$ declare t text; begin for t in select unnest(array['profiles','company_settings','team_members','clients','services','invoices','invoice_items','payments','recurring_schedules','recurring_payments','quotations','proposals','agreements','document_templates','whatsapp_templates','expenses','activity_logs']) loop execute format('drop policy if exists "auth all %s" on public.%I',t,t); execute format('create policy "auth all %s" on public.%I for all to authenticated using (true) with check (true)',t,t); end loop; end $$;
insert into services(name,description,default_price) select * from (values ('Meta Ads Management','Meta campaign management',15000::numeric),('Ad Creative Production','Creative ad production',7000::numeric),('Content Strategy','Content strategy and planning',5000::numeric),('Monthly Marketing Package','Monthly creative + advertising package',25000::numeric)) v(name,description,default_price) where not exists (select 1 from services s where s.name=v.name);

insert into storage.buckets(id,name,public) values ('brand-assets','brand-assets',false) on conflict (id) do nothing;
create policy "brand assets authenticated read" on storage.objects for select to authenticated using (bucket_id='brand-assets');
create policy "brand assets authenticated write" on storage.objects for insert to authenticated with check (bucket_id='brand-assets');
