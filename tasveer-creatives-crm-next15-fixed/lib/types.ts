export type Status="draft"|"sent"|"partially_paid"|"paid"|"overdue"|"cancelled";
export type DocumentType="invoice"|"quotation"|"proposal"|"agreement"|"receipt";
export type Client={id:string;name:string;business_name:string;email?:string;phone?:string;address?:string;gstin?:string;logo_url?:string;notes?:string};
export type Service={id:string;name:string;description?:string;default_price:number;active:boolean};
export type LineItem={id?:string;service_id?:string;name:string;description?:string;quantity:number;rate:number;discount:number;tax_rate:number};
