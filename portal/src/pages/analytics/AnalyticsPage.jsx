import { useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import {
  BarChart, Bar, LineChart, Line, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, Area, AreaChart,
} from 'recharts';
import {
  UsersIcon, HeartIcon, CalendarDaysIcon, BellIcon, BeakerIcon,
  ShieldCheckIcon, ArrowPathIcon, ExclamationTriangleIcon,
  UserGroupIcon, ArrowTrendingUpIcon, ArrowTrendingDownIcon,
  MinusIcon, CurrencyDollarIcon, BuildingOfficeIcon,
} from '@heroicons/react/24/outline';
import StatCard from '../../components/UI/StatCard';
import Spinner from '../../components/UI/Spinner';
import {
  getMemberStats, getAppointmentStats, getMedicationAdherence,
  getAdherenceTrend, getNotificationStats, getLabTestStats,
  getAuthorizationStats, getVitalsPopulationStats, getVitalsAlerts,
  getTreatmentPlanStats, getTopMedications, getAlertSeverityStats,
  getMemberGrowthTrend, getMemberDemographics, getAgeDistribution,
  getPlanTypeDistribution, getEmergencyStats, getAppointmentQuality,
  getCostSummary,
} from '../../api/analytics';

/* ── colours (no purple) ─────────────────────────────────────────────── */
const C = {
  blue:'#003DA5', green:'#7AB800', sky:'#0ea5e9', amber:'#f59e0b',
  red:'#ef4444', teal:'#14b8a6', orange:'#f97316', emerald:'#10b981',
  cyan:'#06b6d4', rose:'#f43f5e', slate:'#64748b',
};
const PIE1 = [C.blue,C.green,C.sky,C.teal,C.amber,C.orange,C.emerald,C.cyan];
const PIE2 = [C.green,C.amber,C.red];
const SEV  = {Critical:C.red,High:C.orange,Medium:C.amber,Low:C.sky,Unknown:'#94a3b8'};
const PERIODS = [{v:7,l:'7 days'},{v:30,l:'30 days'},{v:90,l:'3 months'},{v:180,l:'6 months'}];

/* ── helpers ─────────────────────────────────────────────────────────── */
const card = (ch,sx={}) => (
  <div style={{background:'#fff',borderRadius:12,padding:20,
    boxShadow:'0 1px 4px rgba(0,0,0,0.08)',...sx}}>{ch}</div>
);
const CT = t => (
  <h3 style={{margin:'0 0 14px',fontSize:14,fontWeight:600,color:'#1e293b'}}>{t}</h3>
);
const SH = (title,sub,color='#1e293b') => (
  <div style={{marginBottom:4}}>
    <h2 style={{margin:0,fontSize:16,fontWeight:700,color}}>{title}</h2>
    {sub&&<p style={{margin:'2px 0 0',fontSize:12,color:C.slate}}>{sub}</p>}
  </div>
);
const q = (key,fn,extra={}) => ({
  queryKey:Array.isArray(key)?key:[key],
  queryFn:()=>fn().then(r=>r.data),
  retry:false, staleTime:60000, ...extra,
});
const tip  = {contentStyle:{fontSize:12,borderRadius:6}};
const axis = {tick:{fontSize:11,fill:C.slate}};
const grid = {strokeDasharray:'3 3',stroke:'#f1f5f9'};
const fmt  = n => n==null?'--':Number(n).toLocaleString();

/* ── Trend arrow ─────────────────────────────────────────────────────── */
const Trend = ({pct}) => {
  if(pct==null) return null;
  const up = pct>=0;
  const Icon = pct===0?MinusIcon:up?ArrowTrendingUpIcon:ArrowTrendingDownIcon;
  return (
    <span style={{display:'inline-flex',alignItems:'center',gap:2,
      fontSize:11,fontWeight:600,color:up?C.green:C.red}}>
      <Icon style={{width:12,height:12}}/>
      {Math.abs(pct)}% vs last month
    </span>
  );
};

/* ── Small badge strip ───────────────────────────────────────────────── */
const Badges = ({items}) => (
  <div style={{display:'flex',gap:8,marginBottom:12,flexWrap:'wrap'}}>
    {items.map(s=>(
      <div key={s.label} style={{background:`${s.color}12`,border:`1px solid ${s.color}40`,
        borderRadius:6,padding:'4px 10px',fontSize:12}}>
        <span style={{color:s.color,fontWeight:700}}>{fmt(s.val)}</span>
        <span style={{color:C.slate,marginLeft:4}}>{s.label}</span>
      </div>
    ))}
  </div>
);

/* ── Vitals alert pill ───────────────────────────────────────────────── */
const VAlert = ({label,val,total,color}) => {
  const pct = total>0?Math.round((val/total)*100):0;
  return (
    <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',
      padding:'8px 12px',borderRadius:8,background:`${color}0d`,
      border:`1px solid ${color}30`,marginBottom:8}}>
      <div style={{display:'flex',alignItems:'center',gap:8}}>
        <ExclamationTriangleIcon style={{width:14,height:14,color}}/>
        <span style={{fontSize:13,color:'#1e293b'}}>{label}</span>
      </div>
      <div style={{textAlign:'right'}}>
        <span style={{fontSize:16,fontWeight:700,color}}>{val}</span>
        <span style={{fontSize:11,color:C.slate,marginLeft:4}}>members ({pct}%)</span>
      </div>
    </div>
  );
};

/* ── Stat card with trend ────────────────────────────────────────────── */
const TrendCard = ({title,value,icon:Icon,color,changePct}) => (
  <div style={{background:'#fff',borderRadius:12,padding:'16px 20px',
    boxShadow:'0 1px 4px rgba(0,0,0,0.08)',borderLeft:`4px solid ${color}`}}>
    <div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-start'}}>
      <div>
        <p style={{margin:0,fontSize:12,color:C.slate,fontWeight:500}}>{title}</p>
        <p style={{margin:'6px 0 4px',fontSize:24,fontWeight:700,color:'#1e293b'}}>{value}</p>
        <Trend pct={changePct}/>
      </div>
      <div style={{background:`${color}12`,borderRadius:10,padding:10}}>
        <Icon style={{width:22,height:22,color}}/>
      </div>
    </div>
  </div>
);

/* ── Custom tooltip for cost bar ─────────────────────────────────────── */
const CostTip = ({active,payload}) => {
  if(!active||!payload?.length) return null;
  const d = payload[0].payload;
  return (
    <div style={{background:'#fff',border:'1px solid #e2e8f0',borderRadius:6,padding:'8px 12px',fontSize:12}}>
      <p style={{margin:0,fontWeight:600}}>{d.condition}</p>
      <p style={{margin:'2px 0 0',color:C.blue}}>Avg: {d.currency} {Number(d.avg_cost).toLocaleString()}</p>
      <p style={{margin:'2px 0 0',color:C.slate}}>{d.plans} treatment plans</p>
    </div>
  );
};

const MedTip = ({active,payload}) => {
  if(!active||!payload?.length) return null;
  const d = payload[0].payload;
  return (
    <div style={{background:'#fff',border:'1px solid #e2e8f0',borderRadius:6,padding:'8px 12px',fontSize:12}}>
      <p style={{margin:0,fontWeight:600,color:'#1e293b'}}>{d.name}</p>
      {d.generic_name&&<p style={{margin:'2px 0 0',color:C.slate}}>{d.generic_name}</p>}
      <p style={{margin:'4px 0 0',color:C.blue}}><strong>{d.prescriptions}</strong> active prescriptions</p>
    </div>
  );
};

/* ═══════════════════════════════════════════════════════════════════════ */
export default function AnalyticsPage() {
  const qc = useQueryClient();
  const [period, setPeriod] = useState(30);

  /* queries */
  const {data:mems,   isLoading:mL}  = useQuery(q('a-members',    getMemberStats));
  const {data:appt,   isLoading:aL}  = useQuery(q('a-appts',      getAppointmentStats));
  const {data:adh}                   = useQuery(q('a-adh',        getMedicationAdherence));
  const {data:trend,  isLoading:trL} = useQuery({
    queryKey:['a-adh-trend',period],
    queryFn:()=>getAdherenceTrend(period).then(r=>r.data),
    retry:false, staleTime:60000,
  });
  const {data:notif}                 = useQuery(q('a-notif',      getNotificationStats));
  const {data:lab,    isLoading:lbL} = useQuery(q('a-lab',        getLabTestStats));
  const {data:auth,   isLoading:auL} = useQuery(q('a-auth',       getAuthorizationStats));
  const {data:vPop}                  = useQuery(q('a-vpop',       getVitalsPopulationStats));
  const {data:vAlert, isLoading:vaL} = useQuery(q('a-valert',     getVitalsAlerts));
  const {data:tp,     isLoading:tpL} = useQuery(q('a-tp',         getTreatmentPlanStats));
  const {data:topM,   isLoading:tmL} = useQuery(q('a-topmeds',    getTopMedications));
  const {data:sev,    isLoading:svL} = useQuery(q('a-sev',        getAlertSeverityStats));
  const {data:growth, isLoading:grL} = useQuery(q('a-growth',     getMemberGrowthTrend));
  const {data:demo,   isLoading:dmL} = useQuery(q('a-demo',       getMemberDemographics));
  const {data:age,    isLoading:agL} = useQuery(q('a-age',        getAgeDistribution));
  const {data:plan,   isLoading:plL} = useQuery(q('a-plan',       getPlanTypeDistribution));
  const {data:emerg,  isLoading:emL} = useQuery(q('a-emerg',      getEmergencyStats));
  const {data:apptQ,  isLoading:aqL} = useQuery(q('a-apptq',      getAppointmentQuality));
  const {data:cost,   isLoading:coL} = useQuery(q('a-cost',       getCostSummary));

  /* derived */
  const adherenceRate = adh?.adherence_pct ?? null;
  const apptStatus    = appt?.by_status   || [];
  const monthlyAppt   = appt?.by_month    || [];
  const topHospitals  = appt?.by_hospital || [];
  const notifCh       = notif?.by_channel || [];
  const sevChart      = sev               || [];
  const genderChart   = demo?.by_gender   || [];
  const trendData     = trend             || [];
  const ageData       = age               || [];
  const planData      = plan              || [];
  const emergChart    = emerg?.chart      || [];
  const tpChart       = tp?.chart         || [];
  const costByCondition = cost?.by_condition || [];
  const meds          = topM              || [];

  const totalApptQ    = apptQ?.total || 0;

  return (
    <div style={{display:'flex',flexDirection:'column',gap:28}}>

      {/* ── Header ─────────────────────────────────────────────────── */}
      <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',flexWrap:'wrap',gap:12}}>
        <div>
          <h1 style={{margin:0,fontSize:20,fontWeight:700,color:C.blue}}>Analytics Dashboard</h1>
          <p style={{margin:'2px 0 0',fontSize:13,color:C.slate}}>
            Live insights across all clinical and operational areas
          </p>
        </div>
        <div style={{display:'flex',gap:8,alignItems:'center'}}>
          <span style={{fontSize:12,color:C.slate}}>Adherence trend:</span>
          {PERIODS.map(p=>(
            <button key={p.v} onClick={()=>setPeriod(p.v)} style={{
              padding:'5px 12px',borderRadius:6,fontSize:12,cursor:'pointer',fontWeight:500,
              border:`1px solid ${period===p.v?C.blue:'#e2e8f0'}`,
              background:period===p.v?C.blue:'#f8fafc',
              color:period===p.v?'#fff':C.slate}}>
              {p.l}
            </button>
          ))}
          <button onClick={()=>qc.invalidateQueries()} style={{
            display:'flex',alignItems:'center',gap:5,padding:'6px 14px',
            borderRadius:6,fontSize:12,cursor:'pointer',fontWeight:500,
            border:'1px solid #e2e8f0',background:'#f8fafc',color:C.slate}}>
            <ArrowPathIcon style={{width:14,height:14}}/>Refresh
          </button>
        </div>
      </div>

      {/* ── Section 1: Key Metrics ─────────────────────────────────── */}
      {SH('Key Metrics','Live snapshot — all figures from live database',C.blue)}
      <div style={{display:'grid',gridTemplateColumns:'repeat(auto-fit,minmax(200px,1fr))',gap:14}}>
        <TrendCard title="Total Members"      value={fmt(mems?.total)}          icon={UsersIcon}        color={C.blue}    changePct={null}/>
        <TrendCard title="Active Members"     value={fmt(mems?.active)}         icon={UserGroupIcon}    color={C.green}   changePct={null}/>
        <TrendCard title="New This Month"     value={fmt(mems?.new_this_month)} icon={UsersIcon}        color={C.teal}    changePct={mems?.new_member_change_pct}/>
        <TrendCard title="Adherence Rate"     value={adherenceRate!=null?`${adherenceRate}%`:'--'} icon={HeartIcon} color={C.emerald} changePct={null}/>
        <TrendCard title="Total Appointments" value={fmt(appt?.total)}          icon={CalendarDaysIcon} color={C.sky}     changePct={null}/>
        <TrendCard title="Auth Approval Rate" value={auth?.approval_rate!=null?`${auth.approval_rate}%`:'--'} icon={ShieldCheckIcon} color={C.amber} changePct={null}/>
        <TrendCard title="Lab Tests Overdue"  value={fmt(lab?.overdue)}         icon={BeakerIcon}       color={C.rose}    changePct={null}/>
        <TrendCard title="Notification Success" value={notif?.success_rate!=null?`${notif.success_rate}%`:'--'} icon={BellIcon} color={C.orange} changePct={null}/>
      </div>

      {/* ── Section 2: Medication Adherence Trend ─────────────────── */}
      {SH('Medication Adherence Trend',`Doses taken vs skipped over the last ${period} days`)}
      {card(<>
        {CT(`Daily Taken vs Skipped — Last ${period} days`)}
        {trL?<Spinner/>:trendData.length===0
          ?<p style={{color:'#94a3b8',fontSize:13,textAlign:'center',padding:'40px 0'}}>
            No medication log data for this period
          </p>
          :<ResponsiveContainer width="100%" height={220}>
            <AreaChart data={trendData} margin={{top:4,right:8}}>
              <defs>
                <linearGradient id="gTaken" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%"  stopColor={C.green}   stopOpacity={0.18}/>
                  <stop offset="95%" stopColor={C.green}   stopOpacity={0}/>
                </linearGradient>
                <linearGradient id="gSkipped" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%"  stopColor={C.red}     stopOpacity={0.18}/>
                  <stop offset="95%" stopColor={C.red}     stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid {...grid}/>
              <XAxis dataKey="day" {...axis} tickFormatter={d=>d?.slice(5)}/>
              <YAxis {...axis} allowDecimals={false}/>
              <Tooltip {...tip}/>
              <Legend wrapperStyle={{fontSize:12}}/>
              <Area type="monotone" dataKey="taken"   stroke={C.green} fill="url(#gTaken)"   strokeWidth={2} name="Taken"   dot={false}/>
              <Area type="monotone" dataKey="skipped" stroke={C.red}   fill="url(#gSkipped)" strokeWidth={2} name="Skipped" dot={false}/>
            </AreaChart>
          </ResponsiveContainer>}
      </>)}

      {/* ── Section 3: Member Analytics ───────────────────────────── */}
      {SH('Member Analytics')}
      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:16}}>
        {card(<>
          {CT('Members per Condition')}
          {mL?<Spinner/>:(!mems?.by_condition?.length)
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :<ResponsiveContainer width="100%" height={230}>
              <BarChart data={mems.by_condition} margin={{top:4,right:8}}>
                <CartesianGrid {...grid}/>
                <XAxis dataKey="condition" {...axis}/>
                <YAxis {...axis}/>
                <Tooltip {...tip}/>
                <Bar dataKey="count" fill={C.blue} radius={[4,4,0,0]} name="Members"/>
              </BarChart>
            </ResponsiveContainer>}
        </>)}
        {card(<>
          {CT('Member Registration Trend (12 months)')}
          {grL?<Spinner/>:(!growth.length)
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :<ResponsiveContainer width="100%" height={230}>
              <LineChart data={growth} margin={{top:4,right:8}}>
                <CartesianGrid {...grid}/>
                <XAxis dataKey="month" {...axis}/>
                <YAxis {...axis} allowDecimals={false}/>
                <Tooltip {...tip}/>
                <Line type="monotone" dataKey="count" stroke={C.teal} strokeWidth={2}
                  dot={{fill:C.teal,r:4}} name="New Members"/>
              </LineChart>
            </ResponsiveContainer>}
        </>)}
      </div>

      {/* ── Section 4: Demographics ───────────────────────────────── */}
      {SH('Member Demographics')}
      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:16}}>
        {card(<>
          {CT('Gender Split')}
          {dmL?<Spinner/>:(!genderChart.length)
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :<ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie data={genderChart} cx="50%" cy="50%" innerRadius={45} outerRadius={75}
                  paddingAngle={3} dataKey="value"
                  label={({name,percent})=>`${name} ${(percent*100).toFixed(0)}%`} labelLine={false}>
                  {genderChart.map((_,i)=><Cell key={i} fill={PIE1[i%PIE1.length]}/>)}
                </Pie>
                <Tooltip {...tip}/><Legend wrapperStyle={{fontSize:11}}/>
              </PieChart>
            </ResponsiveContainer>}
        </>)}
        {card(<>
          {CT('Age Distribution')}
          {agL?<Spinner/>:(!ageData.length)
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :<ResponsiveContainer width="100%" height={200}>
              <BarChart data={ageData} margin={{top:4,right:8}}>
                <CartesianGrid {...grid}/>
                <XAxis dataKey="bracket" {...axis}/>
                <YAxis {...axis} allowDecimals={false}/>
                <Tooltip {...tip}/>
                <Bar dataKey="count" radius={[4,4,0,0]} name="Members">
                  {ageData.map((_,i)=><Cell key={i} fill={PIE1[i%PIE1.length]}/>)}
                </Bar>
              </BarChart>
            </ResponsiveContainer>}
        </>)}
        {card(<>
          {CT('Plan Type Distribution')}
          {plL?<Spinner/>:(!planData.length)
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :<ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie data={planData} cx="50%" cy="50%" innerRadius={45} outerRadius={75}
                  paddingAngle={3} dataKey="value"
                  label={({name,percent})=>`${(percent*100).toFixed(0)}%`} labelLine={false}>
                  {planData.map((_,i)=><Cell key={i} fill={PIE1[i%PIE1.length]}/>)}
                </Pie>
                <Tooltip {...tip}/><Legend wrapperStyle={{fontSize:11}}/>
              </PieChart>
            </ResponsiveContainer>}
        </>)}
      </div>

      {/* ── Section 5: Appointments ───────────────────────────────── */}
      {SH('Appointments')}
      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:16}}>
        {card(<>
          {CT('Monthly Volume')}
          {aL?<Spinner/>:(!monthlyAppt.length)
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :<ResponsiveContainer width="100%" height={220}>
              <LineChart data={monthlyAppt} margin={{top:4,right:8}}>
                <CartesianGrid {...grid}/>
                <XAxis dataKey="month" {...axis}/>
                <YAxis {...axis} allowDecimals={false}/>
                <Tooltip {...tip}/>
                <Line type="monotone" dataKey="count" stroke={C.sky} strokeWidth={2}
                  dot={{fill:C.sky,r:4}} name="Appointments"/>
              </LineChart>
            </ResponsiveContainer>}
        </>)}
        {card(<>
          {CT('Status Breakdown')}
          {aL?<Spinner/>:(!apptStatus.length)
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :<ResponsiveContainer width="100%" height={220}>
              <PieChart>
                <Pie data={apptStatus} cx="50%" cy="50%" innerRadius={50} outerRadius={80}
                  paddingAngle={3} dataKey="value"
                  label={({name,percent})=>`${name} ${(percent*100).toFixed(0)}%`} labelLine={false}>
                  {apptStatus.map((_,i)=><Cell key={i} fill={PIE1[i%PIE1.length]}/>)}
                </Pie>
                <Tooltip {...tip}/><Legend wrapperStyle={{fontSize:11}}/>
              </PieChart>
            </ResponsiveContainer>}
        </>)}
      </div>

      {/* ── Section 5b: Appointment Quality + Top Hospitals ────────── */}
      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:16}}>
        {card(<>
          {CT('Appointment Quality Metrics')}
          {aqL?<Spinner/>:!apptQ
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :<>
              <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:10,marginBottom:16}}>
                {[
                  {label:'Completion Rate', val:`${apptQ.completion_rate}%`, color:C.green},
                  {label:'No-Show Rate',    val:`${apptQ.no_show_rate}%`,    color:C.rose},
                  {label:'Cancel Rate',     val:`${apptQ.cancel_rate}%`,     color:C.amber},
                ].map(m=>(
                  <div key={m.label} style={{background:`${m.color}0d`,border:`1px solid ${m.color}30`,
                    borderRadius:8,padding:'12px 14px',textAlign:'center'}}>
                    <p style={{margin:0,fontSize:22,fontWeight:700,color:m.color}}>{m.val}</p>
                    <p style={{margin:'4px 0 0',fontSize:11,color:C.slate}}>{m.label}</p>
                  </div>
                ))}
              </div>
              <Badges items={[
                {label:'No-shows',  val:apptQ.no_shows,  color:C.rose},
                {label:'Cancelled', val:apptQ.cancelled, color:C.amber},
                {label:'Completed', val:apptQ.completed, color:C.green},
                {label:'Total',     val:apptQ.total,     color:C.sky},
              ]}/>
            </>}
        </>)}
        {card(<>
          {CT('Top Hospitals by Appointments')}
          {aL?<Spinner/>:(!topHospitals.length)
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :<ResponsiveContainer width="100%" height={220}>
              <BarChart data={topHospitals.slice(0,7)} layout="vertical" margin={{left:8}}>
                <CartesianGrid {...grid} horizontal={false}/>
                <XAxis type="number" {...axis} allowDecimals={false}/>
                <YAxis type="category" dataKey="hospital" {...axis} width={130}/>
                <Tooltip {...tip}/>
                <Bar dataKey="count" fill={C.sky} radius={[0,4,4,0]} name="Appointments">
                  {topHospitals.slice(0,7).map((_,i)=>(
                    <Cell key={i} fill={[C.blue,C.sky,C.teal,C.emerald,C.cyan,C.green,C.amber][i%7]}/>
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>}
        </>)}
      </div>

      {/* ── Section 6: Emergency ───────────────────────────────────── */}
      {SH('Emergency Alerts')}
      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:16}}>
        {card(<>
          {CT('Emergency Requests Summary')}
          {emL?<Spinner/>:!emerg
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :<>
              <div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:10,marginBottom:16}}>
                {[
                  {label:'Pending',    val:emerg.pending,    color:C.rose},
                  {label:'Dispatched', val:emerg.dispatched, color:C.amber},
                  {label:'Resolved',   val:emerg.resolved,   color:C.green},
                ].map(m=>(
                  <div key={m.label} style={{background:`${m.color}0d`,border:`1px solid ${m.color}30`,
                    borderRadius:8,padding:'12px 14px',textAlign:'center'}}>
                    <p style={{margin:0,fontSize:22,fontWeight:700,color:m.color}}>{fmt(m.val)}</p>
                    <p style={{margin:'4px 0 0',fontSize:11,color:C.slate}}>{m.label}</p>
                  </div>
                ))}
              </div>
              {emerg.avg_resolve_mins!=null&&(
                <p style={{margin:'0 0 10px',fontSize:12,color:C.slate,textAlign:'center'}}>
                  Avg resolution time: <strong style={{color:C.teal}}>{emerg.avg_resolve_mins} min</strong>
                </p>
              )}
              <p style={{margin:0,fontSize:12,color:C.slate}}>
                This month: <strong>{fmt(emerg.this_month)}</strong> emergency requests
              </p>
            </>}
        </>)}
        {card(<>
          {CT('Emergency Status Split')}
          {emL?<Spinner/>:(!emergChart.length||emergChart.every(e=>e.value===0))
            ?<p style={{color:'#94a3b8',fontSize:13}}>No emergency data</p>
            :<ResponsiveContainer width="100%" height={220}>
              <PieChart>
                <Pie data={emergChart.filter(e=>e.value>0)} cx="50%" cy="50%"
                  innerRadius={50} outerRadius={80} paddingAngle={3} dataKey="value"
                  label={({name,percent})=>`${name} ${(percent*100).toFixed(0)}%`} labelLine={false}>
                  {[C.rose,C.amber,C.green].map((c,i)=><Cell key={i} fill={c}/>)}
                </Pie>
                <Tooltip {...tip}/><Legend wrapperStyle={{fontSize:12}}/>
              </PieChart>
            </ResponsiveContainer>}
        </>)}
      </div>

      {/* ── Section 7: Clinical ───────────────────────────────────── */}
      {SH('Clinical Overview')}
      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:16}}>
        {card(<>
          {CT('Lab Tests by Type')}
          {lbL?<Spinner/>:(!lab?.by_type?.length)
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :<>
              <Badges items={[
                {label:'Pending',     val:lab.pending,     color:C.amber},
                {label:'In Progress', val:lab.in_progress, color:C.sky},
                {label:'Completed',   val:lab.completed,   color:C.green},
                {label:'Overdue',     val:lab.overdue,     color:C.rose},
              ]}/>
              <ResponsiveContainer width="100%" height={190}>
                <BarChart data={lab.by_type} layout="vertical" margin={{left:8}}>
                  <CartesianGrid {...grid} horizontal={false}/>
                  <XAxis type="number" {...axis} allowDecimals={false}/>
                  <YAxis type="category" dataKey="type" {...axis} width={110}/>
                  <Tooltip {...tip}/>
                  <Bar dataKey="count" fill={C.teal} radius={[0,4,4,0]} name="Tests"/>
                </BarChart>
              </ResponsiveContainer>
            </>}
        </>)}
        {card(<>
          {CT('Treatment Plans Status')}
          {tpL?<Spinner/>:!tp
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :<>
              <Badges items={[
                {label:'Active',    val:tp.active,    color:C.green},
                {label:'Pending',   val:tp.pending,   color:C.amber},
                {label:'Completed', val:tp.completed, color:C.sky},
                {label:'Cancelled', val:tp.cancelled, color:C.red},
              ]}/>
              <ResponsiveContainer width="100%" height={190}>
                <PieChart>
                  <Pie data={tpChart} cx="50%" cy="50%" innerRadius={45} outerRadius={75}
                    paddingAngle={3} dataKey="value"
                    label={({name,percent})=>`${name} ${(percent*100).toFixed(0)}%`} labelLine={false}>
                    {[C.green,C.amber,C.sky,C.red].map((c,i)=><Cell key={i} fill={c}/>)}
                  </Pie>
                  <Tooltip {...tip}/>
                </PieChart>
              </ResponsiveContainer>
            </>}
        </>)}
      </div>

      {/* ── Section 8: Cost Summary ───────────────────────────────── */}
      {SH('Treatment Plan Costs')}
      {card(<>
        {coL?<Spinner/>:!cost||cost.plan_count===0
          ?<p style={{color:'#94a3b8',fontSize:13}}>No cost data recorded yet</p>
          :<>
            <div style={{display:'flex',gap:12,marginBottom:16,flexWrap:'wrap'}}>
              {[
                {label:'Total Spend',   val:`${cost.currency} ${Number(cost.total_cost).toLocaleString()}`,  color:C.blue},
                {label:'Average Cost',  val:`${cost.currency} ${Number(cost.avg_cost).toLocaleString()}`,    color:C.teal},
                {label:'Highest Plan',  val:`${cost.currency} ${Number(cost.max_cost).toLocaleString()}`,    color:C.amber},
                {label:'Plans w/ Cost', val:cost.plan_count,                                                  color:C.green},
              ].map(m=>(
                <div key={m.label} style={{background:`${m.color}0d`,border:`1px solid ${m.color}30`,
                  borderRadius:8,padding:'10px 16px',flex:1,minWidth:140}}>
                  <p style={{margin:0,fontSize:11,color:C.slate}}>{m.label}</p>
                  <p style={{margin:'4px 0 0',fontSize:18,fontWeight:700,color:m.color}}>{m.val}</p>
                </div>
              ))}
            </div>
            {costByCondition.length>0&&(
              <ResponsiveContainer width="100%" height={200}>
                <BarChart data={costByCondition} layout="vertical" margin={{left:8}}>
                  <CartesianGrid {...grid} horizontal={false}/>
                  <XAxis type="number" {...axis}/>
                  <YAxis type="category" dataKey="condition" {...axis} width={120}/>
                  <Tooltip content={<CostTip/>}/>
                  <Bar dataKey="avg_cost" fill={C.blue} radius={[0,4,4,0]} name="Avg Cost (UGX)"/>
                </BarChart>
              </ResponsiveContainer>
            )}
          </>}
      </>)}

      {/* ── Section 9: Authorizations & Alert Severity ───────────── */}
      {SH('Authorizations & Alerts')}
      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:16}}>
        {card(<>
          {CT('Authorization Requests')}
          {auL?<Spinner/>:!auth
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :<>
              <div style={{display:'flex',gap:8,marginBottom:14}}>
                {[
                  {label:'Approved',color:C.green,val:auth.approved},
                  {label:'Pending', color:C.amber, val:auth.pending},
                  {label:'Rejected',color:C.red,   val:auth.rejected},
                ].map(s=>(
                  <div key={s.label} style={{background:`${s.color}12`,border:`1px solid ${s.color}40`,
                    borderRadius:6,padding:'4px 10px',fontSize:12,flex:1,textAlign:'center'}}>
                    <p style={{margin:0,fontSize:20,fontWeight:700,color:s.color}}>{s.val}</p>
                    <p style={{margin:0,color:C.slate,fontSize:11}}>{s.label}</p>
                  </div>
                ))}
              </div>
              <ResponsiveContainer width="100%" height={180}>
                <PieChart>
                  <Pie data={auth.chart} cx="50%" cy="50%" innerRadius={45} outerRadius={75}
                    paddingAngle={3} dataKey="value"
                    label={({name,percent})=>`${name} ${(percent*100).toFixed(0)}%`} labelLine={false}>
                    {PIE2.map((c,i)=><Cell key={i} fill={c}/>)}
                  </Pie>
                  <Tooltip {...tip}/>
                </PieChart>
              </ResponsiveContainer>
            </>}
        </>)}
        {card(<>
          {CT('Alert Severity (Last 30 days)')}
          {svL?<Spinner/>:(!sevChart.length)
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :<ResponsiveContainer width="100%" height={240}>
              <PieChart>
                <Pie data={sevChart} cx="50%" cy="50%" innerRadius={50} outerRadius={80}
                  paddingAngle={3} dataKey="value"
                  label={({name,percent})=>`${name} ${(percent*100).toFixed(0)}%`} labelLine={false}>
                  {sevChart.map((s,i)=><Cell key={i} fill={SEV[s.name]||PIE1[i%PIE1.length]}/>)}
                </Pie>
                <Tooltip {...tip}/><Legend wrapperStyle={{fontSize:12}}/>
              </PieChart>
            </ResponsiveContainer>}
        </>)}
      </div>

      {/* ── Section 10: Population Vitals + Out-of-Range ─────────── */}
      {SH('Population Health','Averages and out-of-range flags based on last 30 days of vitals')}
      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:16}}>
        {card(<>
          {CT('Population Vitals Averages')}
          {!vPop
            ?<p style={{color:'#94a3b8',fontSize:13}}>No vitals data</p>
            :<div style={{display:'flex',flexDirection:'column',gap:10}}>
              {[
                {label:'Avg Blood Sugar',  val:vPop.avg_blood_sugar, unit:'mmol/L',color:C.amber,  normal:'4.0-7.8'},
                {label:'Avg Systolic BP',  val:vPop.avg_systolic,    unit:'mmHg',  color:C.red,    normal:'< 120'},
                {label:'Avg Diastolic BP', val:vPop.avg_diastolic,   unit:'mmHg',  color:C.orange, normal:'< 80'},
                {label:'Avg Heart Rate',   val:vPop.avg_heart_rate,  unit:'bpm',   color:C.teal,   normal:'60-100'},
              ].map(v=>(
                <div key={v.label} style={{display:'flex',alignItems:'center',justifyContent:'space-between',
                  padding:'10px 14px',borderRadius:8,background:'#f8fafc',
                  borderLeft:`4px solid ${v.color}`}}>
                  <div>
                    <p style={{margin:0,fontSize:12,color:C.slate}}>{v.label}</p>
                    <p style={{margin:'2px 0 0',fontSize:11,color:'#94a3b8'}}>Normal: {v.normal}</p>
                  </div>
                  <span style={{fontSize:22,fontWeight:700,color:v.color}}>
                    {v.val??'--'}<span style={{fontSize:12,fontWeight:400,color:'#94a3b8',marginLeft:3}}>{v.unit}</span>
                  </span>
                </div>
              ))}
              <p style={{margin:'4px 0 0',fontSize:11,color:'#94a3b8',textAlign:'center'}}>
                Based on {vPop.members_with_vitals} members with recent vitals
              </p>
            </div>}
        </>)}
        {card(<>
          {CT('Out-of-Range Vitals Flags')}
          {vaL?<Spinner/>:!vAlert
            ?<p style={{color:'#94a3b8',fontSize:13}}>No data</p>
            :vAlert.members_with_vitals===0
            ?<p style={{color:'#94a3b8',fontSize:13,textAlign:'center',padding:'30px 0'}}>
              No vitals recorded in last 30 days
            </p>
            :<>
              <p style={{margin:'0 0 12px',fontSize:12,color:C.slate}}>
                Members with abnormal readings in the last 30 days:
              </p>
              <VAlert label="High Blood Sugar (>10 mmol/L)" val={vAlert.high_blood_sugar} total={vAlert.members_with_vitals} color={C.amber}/>
              <VAlert label="High Systolic BP (>140 mmHg)"  val={vAlert.high_systolic}     total={vAlert.members_with_vitals} color={C.red}/>
              <VAlert label="High Diastolic BP (>90 mmHg)"  val={vAlert.high_diastolic}    total={vAlert.members_with_vitals} color={C.orange}/>
              <VAlert label="Abnormal Heart Rate"            val={vAlert.abnormal_hr}        total={vAlert.members_with_vitals} color={C.rose}/>
            </>}
        </>)}
      </div>

      {/* ── Section 11: Top Medications ───────────────────────────── */}
      {SH('Top 5 Most Prescribed Medications','Currently active prescriptions')}
      {card(<>
        {tmL?<Spinner/>:(!meds.length)
          ?<p style={{color:'#94a3b8',fontSize:13}}>No prescription data</p>
          :<ResponsiveContainer width="100%" height={200}>
            <BarChart data={meds} layout="vertical" margin={{left:20}}>
              <CartesianGrid {...grid} horizontal={false}/>
              <XAxis type="number" {...axis} allowDecimals={false}/>
              <YAxis type="category" dataKey="name" {...axis} width={160}/>
              <Tooltip content={<MedTip/>}/>
              <Bar dataKey="prescriptions" fill={C.blue} radius={[0,4,4,0]} name="Prescriptions"/>
            </BarChart>
          </ResponsiveContainer>}
      </>)}

      {/* ── Section 12: Operational ───────────────────────────────── */}
      {SH('Operational')}
      {card(<>
        {CT('Notification Delivery by Channel (Last 30 days)')}
        {!notifCh.length
          ?<p style={{color:'#94a3b8',fontSize:13}}>No notification data</p>
          :<ResponsiveContainer width="100%" height={220}>
            <BarChart data={notifCh} margin={{top:4,right:8}}>
              <CartesianGrid {...grid}/>
              <XAxis dataKey="channel" {...axis}/>
              <YAxis {...axis} allowDecimals={false}/>
              <Tooltip {...tip}/><Legend wrapperStyle={{fontSize:12}}/>
              <Bar dataKey="sent"   fill={C.green} radius={[4,4,0,0]} name="Sent"/>
              <Bar dataKey="failed" fill={C.red}   radius={[4,4,0,0]} name="Failed"/>
            </BarChart>
          </ResponsiveContainer>}
      </>)}

    </div>
  );
}
