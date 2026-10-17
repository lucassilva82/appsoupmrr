import React from 'react';
import {
	AbsoluteFill,
	Audio,
	Easing,
	Freeze,
	Img,
	interpolate,
	OffthreadVideo,
	random,
	Sequence,
	spring,
	staticFile,
	useCurrentFrame,
	useVideoConfig,
} from 'remotion';
import {Circle, Underline} from '@remotion/rough-notation';
import {PARTES, Trecho} from './roteiro';
import {ATRASO_VOZ, AUDIO, Bloco, focoEm, FPS, montar, noTrecho, PecaNoTempo} from './tempo';

// ── Identidade visual (cores do app, lib/utils/app_theme.dart) ─────────────
const COR = {
	fundo1: '#05142A',
	fundo2: '#030B18',
	acao: '#0565B5',
	acaoClara: '#087BCC',
	azulClaro: '#42A5F5',
	ouro: '#FFB300',
	ouroClaro: '#FFD54F',
	verde: '#6EE7A0',
	texto: '#E6EDF3',
	suave: 'rgba(230,237,243,0.72)',
};
const FONTE = 'Lato, system-ui, sans-serif';
const estiloFonte = `
@font-face { font-family: 'Lato'; src: url('${staticFile('img/Lato-Regular.ttf')}'); font-weight: 400; }
@font-face { font-family: 'Lato'; src: url('${staticFile('img/Lato-Bold.ttf')}'); font-weight: 700; }
`;

const SAIDA = Easing.bezier(0.16, 1, 0.3, 1); // desacelera no fim
const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const s = (seg: number) => Math.round(seg * FPS);

// ── Telefone ────────────────────────────────────────────────────────────────
const TELA_L = 600; // largura da tela em px
const K = TELA_L / 402; // px por ponto
const TELA_A = 874 * K;
const BORDA = 13;
const TEL_X = (1080 - TELA_L) / 2 - BORDA;
const TEL_Y = 318;

// ── Composição ─────────────────────────────────────────────────────────────

export const Tutorial: React.FC = () => {
	const {blocos} = montar();
	return (
		<AbsoluteFill style={{fontFamily: FONTE, color: COR.texto}}>
			<style>{estiloFonte}</style>
			<Fundo />
			{blocos.map((b, i) => (
				<Sequence key={i} from={s(b.ini)} durationInFrames={s(b.dur)} premountFor={30}>
					{b.tipo === 'cartao' ? (
						<CartaoParte parte={b.parte} dur={b.dur} />
					) : (
						<BlocoTrecho bloco={b} anterior={blocos[i - 1]} />
					)}
				</Sequence>
			))}
		</AbsoluteFill>
	);
};

const Som: React.FC<{arquivo: string; aos: number; volume?: number}> = ({arquivo, aos, volume = 0.5}) =>
	aos < 0 ? null : (
		<Sequence from={s(aos)} durationInFrames={s(2)} layout="none">
			<Audio src={staticFile(`sfx/${arquivo}.wav`)} volume={volume} />
		</Sequence>
	);

const Fundo: React.FC = () => {
	const f = useCurrentFrame();
	const blob = (fase: number, raio: number, cor: string) => {
		const x = 50 + 30 * Math.sin(f / 140 + fase);
		const y = 40 + 25 * Math.cos(f / 170 + fase * 1.7);
		return `radial-gradient(circle at ${x}% ${y}%, ${cor}, transparent ${raio}%)`;
	};
	return (
		<AbsoluteFill style={{background: `linear-gradient(180deg, ${COR.fundo1} 0%, ${COR.fundo2} 100%)`}}>
			<Img
				src={staticFile('img/entradacapa.png')}
				style={{position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', opacity: 0.05, filter: 'blur(6px)'}}
			/>
			<AbsoluteFill
				style={{
					background: [blob(0, 45, 'rgba(8,123,204,0.30)'), blob(2.4, 40, 'rgba(66,165,245,0.16)'), blob(4.1, 35, 'rgba(255,179,0,0.06)')].join(','),
				}}
			/>
		</AbsoluteFill>
	);
};

// ── Linhas de circuito que se desenham (abertura e encerramento) ────────────

const CAMINHOS_CIRCUITO = [
	'M -20 300 H 180 L 260 380 H 420',
	'M 1100 260 H 900 L 820 340 H 660',
	'M -20 1500 H 140 L 230 1410 H 380',
	'M 1100 1560 H 930 L 850 1480 H 700',
	'M 540 -20 V 120 L 600 180 V 230',
	'M 160 1940 V 1780 L 240 1700 H 330',
	'M 920 1940 V 1800 L 840 1720 H 760',
];

const Circuito: React.FC<{aos?: number; opacidade?: number}> = ({aos = 0, opacidade = 0.7}) => {
	const f = useCurrentFrame();
	return (
		<svg width={1080} height={1920} style={{position: 'absolute', inset: 0, opacity: opacidade}}>
			<defs>
				<filter id="brilho">
					<feGaussianBlur stdDeviation="4" result="b" />
					<feMerge>
						<feMergeNode in="b" />
						<feMergeNode in="SourceGraphic" />
					</feMerge>
				</filter>
			</defs>
			{CAMINHOS_CIRCUITO.map((d, i) => {
				const p = interpolate(f, [s(aos) + i * 3, s(aos) + i * 3 + 24], [0, 1], {...clamp, easing: SAIDA});
				return (
					<g key={i} filter="url(#brilho)">
						<path d={d} fill="none" stroke={COR.azulClaro} strokeWidth={4} pathLength={1} strokeDasharray={1} strokeDashoffset={1 - p} strokeLinecap="round" />
					</g>
				);
			})}
		</svg>
	);
};

/** Faixa de luz que atravessa um elemento (brilho). */
const Brilho: React.FC<{aos: number; raio?: number}> = ({aos, raio = 0}) => {
	const f = useCurrentFrame();
	const x = interpolate(f, [s(aos), s(aos) + 18], [-120, 220], clamp);
	if (f < s(aos) || f > s(aos) + 18) return null;
	return (
		<div style={{position: 'absolute', inset: 0, borderRadius: raio, overflow: 'hidden', pointerEvents: 'none'}}>
			<div
				style={{
					position: 'absolute',
					top: '-20%',
					bottom: '-20%',
					left: `${x}%`,
					width: '35%',
					transform: 'skewX(-20deg)',
					background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.55), transparent)',
				}}
			/>
		</div>
	);
};

// ── Trecho ──────────────────────────────────────────────────────────────────

const BlocoTrecho: React.FC<{bloco: Extract<Bloco, {tipo: 'trecho'}>; anterior?: Bloco}> = ({bloco, anterior}) => {
	const {trecho, pecas} = bloco;
	const audio = AUDIO[trecho.audio];
	const prevTrecho = anterior?.tipo === 'trecho' ? anterior.trecho : undefined;
	const primeiroDaParte = !prevTrecho || prevTrecho.parte !== trecho.parte;
	const passoAntes = !primeiroDaParte && prevTrecho?.passo !== undefined ? prevTrecho.passo : trecho.passo ?? 0;
	return (
		<AbsoluteFill>
			{trecho.cena === 'novidade' && <CenaNovidade />}
			{trecho.cena === 'pergunta' && <CenaPergunta />}
			{trecho.cena === 'caminhos' && <CenaCaminhos />}
			{trecho.parte === 3 && <Encerramento />}
			{(trecho.parte === 1 || trecho.parte === 2) && (
				<>
					<Cabecalho parte={trecho.parte} entra={primeiroDaParte} />
					<Passos parte={trecho.parte} de={passoAntes} para={trecho.passo ?? 0} />
					<Telefone trecho={trecho} pecas={pecas} entra={primeiroDaParte} />
				</>
			)}
			<Sequence from={s(ATRASO_VOZ)}>
				<Audio src={staticFile(audio.arquivo)} />
				{/* Na abertura e no encerramento o texto já está na tela. */}
				{(trecho.parte === 1 || trecho.parte === 2) && <Legenda palavras={audio.palavras} parte={trecho.parte} />}
			</Sequence>
		</AbsoluteFill>
	);
};

const Cabecalho: React.FC<{parte: 1 | 2; entra: boolean}> = ({parte, entra}) => {
	const f = useCurrentFrame();
	const {fps} = useVideoConfig();
	const p = PARTES[parte];
	const k = entra ? spring({frame: f, fps, config: {damping: 14}}) : 1;
	return (
		<div
			style={{
				position: 'absolute',
				top: 56,
				left: 60,
				right: 60,
				display: 'flex',
				alignItems: 'center',
				gap: 26,
				opacity: k,
				transform: `translateY(${(1 - k) * -40}px)`,
			}}
		>
			<div
				style={{
					position: 'relative',
					width: 112,
					height: 112,
					borderRadius: 34,
					background: `linear-gradient(160deg, ${COR.acaoClara}, ${COR.acao})`,
					display: 'flex',
					alignItems: 'center',
					justifyContent: 'center',
					fontSize: 68,
					fontWeight: 700,
					boxShadow: '0 12px 30px rgba(0,0,0,0.35), inset 0 1px 0 rgba(255,255,255,0.25)',
					flexShrink: 0,
				}}
			>
				{p.numero}
			</div>
			<div>
				<div style={{fontSize: 58, fontWeight: 700, lineHeight: 1.05}}>{p.titulo}</div>
				<div style={{fontSize: 32, color: COR.azulClaro, marginTop: 6}}>{p.sub}</div>
			</div>
		</div>
	);
};

/** Barra de passos: mostra em que ponto do caminho o militar está. */
const Passos: React.FC<{parte: 1 | 2; de: number; para: number}> = ({parte, de, para}) => {
	const f = useCurrentFrame();
	const {fps} = useVideoConfig();
	const passos = PARTES[parte].passos;
	const k = spring({frame: f - 4, fps, config: {damping: 18}});
	const atual = de + (para - de) * k;
	const larg = 960;
	const passo = larg / (passos.length - 1);
	return (
		<div style={{position: 'absolute', top: 206, left: 60, width: larg, height: 80}}>
			<div style={{position: 'absolute', top: 13, left: 0, right: 0, height: 6, borderRadius: 3, background: 'rgba(255,255,255,0.12)'}} />
			<div
				style={{
					position: 'absolute',
					top: 13,
					left: 0,
					width: atual * passo,
					height: 6,
					borderRadius: 3,
					background: `linear-gradient(90deg, ${COR.acaoClara}, ${COR.azulClaro})`,
					boxShadow: `0 0 14px ${COR.azulClaro}`,
				}}
			/>
			{passos.map((nome, i) => {
				const feito = i <= atual + 0.01;
				const eAtual = Math.round(atual) === i;
				const pulso = eAtual ? 1 + 0.12 * Math.sin(f / 6) * (1 - Math.min(1, f / 40)) : 1;
				return (
					<div key={nome} style={{position: 'absolute', left: i * passo, top: 0, transform: 'translateX(-50%)', display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
						<div
							style={{
								width: 32,
								height: 32,
								borderRadius: 16,
								background: feito ? COR.azulClaro : '#1b2533',
								border: `3px solid ${feito ? '#cfe8ff' : 'rgba(255,255,255,0.25)'}`,
								boxShadow: eAtual ? `0 0 0 8px rgba(66,165,245,0.25), 0 0 22px ${COR.azulClaro}` : 'none',
								transform: `scale(${pulso})`,
							}}
						/>
						<div style={{marginTop: 8, fontSize: 24, fontWeight: eAtual ? 700 : 400, color: eAtual ? '#fff' : feito ? COR.suave : 'rgba(230,237,243,0.4)', whiteSpace: 'nowrap'}}>
							{nome}
						</div>
					</div>
				);
			})}
		</div>
	);
};

const Telefone: React.FC<{trecho: Trecho; pecas: PecaNoTempo[]; entra: boolean}> = ({trecho, pecas, entra}) => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();
	const t = frame / FPS;
	const foco = focoEm(pecas, t);
	const tx = Math.min(0, Math.max(TELA_L - TELA_L * foco.s, TELA_L / 2 - foco.x * K * foco.s));
	const ty = Math.min(0, Math.max(TELA_A - TELA_A * foco.s, TELA_A * 0.42 - foco.y * K * foco.s));
	const pecaAtual = pecas.find((x) => t >= x.ini && t < x.fim) ?? pecas[pecas.length - 1];
	const src = (p: {video?: string}) => staticFile(`gravacoes/${p.video ?? trecho.video}.mp4`);
	const toques = (trecho.toques ?? []).map((q) => ({...q, tt: noTrecho(pecas, q.t, q.video)}));

	// Entrada do telefone no começo de cada caminho e um leve "soco" a cada toque.
	const k = entra ? spring({frame, fps, config: {damping: 15, mass: 0.9}}) : 1;
	const soco = toques.reduce((acc, q) => {
		if (q.tt === null) return acc;
		const d = t - q.tt;
		return acc + (d > 0 && d < 0.35 ? Math.sin((d / 0.35) * Math.PI) * 0.018 : 0);
	}, 0);
	const flutua = Math.sin(frame / 45) * 6;
	const sucessoT = trecho.sucesso !== undefined ? noTrecho(pecas, trecho.sucesso) : null;

	return (
		<>
			<div
				style={{
					position: 'absolute',
					left: TEL_X,
					top: TEL_Y,
					width: TELA_L + BORDA * 2,
					height: TELA_A + BORDA * 2,
					borderRadius: 92,
					background: 'linear-gradient(160deg, #1d2633, #0b0f16 40%)',
					boxShadow: '0 0 0 3px #2a3442, 0 40px 90px rgba(0,0,0,0.6), 0 0 140px rgba(8,123,204,0.22)',
					padding: BORDA,
					transform: `translateY(${(1 - k) * 700 + flutua}px) rotate(${(1 - k) * 8}deg) scale(${1 + soco})`,
					opacity: Math.min(1, k * 1.5),
				}}
			>
				<div style={{position: 'relative', width: TELA_L, height: TELA_A, borderRadius: 80, overflow: 'hidden', background: '#000'}}>
					<div
						style={{
							position: 'absolute',
							width: TELA_L,
							height: TELA_A,
							transformOrigin: '0 0',
							transform: `translate(${tx}px, ${ty}px) scale(${foco.s})`,
						}}
					>
						{pecas.map((p, i) => (
							<Sequence key={i} from={s(p.ini)} durationInFrames={Math.max(1, s(p.fim) - s(p.ini))} layout="none">
								{'congela' in p ? (
									<Freeze frame={0}>
										<OffthreadVideo src={src(p)} startFrom={s(p.congela)} muted style={{width: TELA_L, height: TELA_A}} />
									</Freeze>
								) : (
									<OffthreadVideo src={src(p)} startFrom={s(p.de)} muted style={{width: TELA_L, height: TELA_A}} />
								)}
							</Sequence>
						))}
						{pecaAtual?.borrar && (
							<div
								style={{
									position: 'absolute',
									left: 8 * K,
									top: 122 * K,
									width: 386 * K,
									height: 204 * K,
									borderRadius: 18 * K,
									backdropFilter: 'blur(22px)',
									background: 'rgba(5,20,42,0.35)',
								}}
							/>
						)}
					</div>
					{toques.map((q, i) =>
						q.tt === null ? null : (
							<CirculoToque
								key={i}
								t={t - q.tt}
								semente={i + 3}
								x={tx + q.x * K * foco.s}
								y={ty + q.y * K * foco.s}
								w={q.w * K * foco.s}
								h={q.h * K * foco.s}
							/>
						),
					)}
					{trecho.email && <AvisoEmail trecho={trecho} pecas={pecas} />}
					{sucessoT !== null && <Festa t={t - sucessoT} />}
					{entra && <Brilho aos={0.5} raio={80} />}
				</div>
			</div>
			{toques.map((q, i) => (q.tt === null ? null : <Som key={i} arquivo="mouse-click" aos={q.tt - 0.02} volume={0.35} />))}
			{sucessoT !== null && <Som arquivo="ding" aos={sucessoT + 0.1} volume={0.35} />}
			{entra && <Som arquivo="whoosh" aos={0} volume={0.45} />}
		</>
	);
};

/**
 * Círculo desenhado à mão em volta do elemento tocado: começa a ser
 * desenhado antes do toque, fica no toque e some quando a tela muda.
 */
const CirculoToque: React.FC<{t: number; x: number; y: number; w: number; h: number; semente: number}> = ({t, x, y, w, h, semente}) => {
	if (t < -0.75 || t > 0.45) return null;
	const desenho = interpolate(t, [-0.7, -0.08], [0, 1], {...clamp, easing: Easing.bezier(0.55, 0, 0.25, 1)});
	const some = interpolate(t, [0.12, 0.4], [1, 0], clamp);
	// Campos largos: a elipse cresce para cima e para baixo, não para os lados.
	const largo = w > TELA_L * 0.7;
	const pad = largo ? {left: -4, right: -4, top: 26, bottom: 26} : {left: 18, right: 18, top: 16, bottom: 16};
	const pontoOp = interpolate(t, [-0.06, 0, 0.3, 0.5], [0, 1, 1, 0], clamp);
	const onda = interpolate(t, [0, 0.45], [0.4, 1.6], {...clamp, easing: SAIDA});
	return (
		<>
			<div style={{position: 'absolute', left: x - w / 2, top: y - h / 2, opacity: some, filter: 'drop-shadow(0 0 8px rgba(255,179,0,0.7))'}}>
				<Circle
					progress={desenho}
					color={COR.ouro}
					strokeWidth={5}
					seed={semente}
					iterations={1}
					roughness={1.1}
					padding={pad}
				>
					<div style={{width: w, height: h}} />
				</Circle>
			</div>
			{/* ponto do dedo no instante do toque */}
			<div
				style={{
					position: 'absolute',
					left: x - 28,
					top: y - 28,
					width: 56,
					height: 56,
					borderRadius: 28,
					border: '3px solid rgba(255,255,255,0.9)',
					background: 'rgba(255,255,255,0.18)',
					transform: `scale(${onda})`,
					opacity: pontoOp * (1 - (onda - 0.4) / 1.6),
				}}
			/>
		</>
	);
};

/** Explosão de partículas quando aparece a tela de sucesso. */
const Festa: React.FC<{t: number}> = ({t}) => {
	if (t < 0 || t > 1.6) return null;
	const cores = [COR.ouro, COR.azulClaro, COR.verde, '#ffffff'];
	return (
		<>
			{Array.from({length: 46}).map((_, i) => {
				const ang = random(`a${i}`) * Math.PI * 2;
				const vel = 280 + random(`v${i}`) * 420;
				const d = vel * (1 - Math.exp(-t * 3.2));
				const x = TELA_L / 2 + Math.cos(ang) * d;
				const y = TELA_A * 0.24 + Math.sin(ang) * d + 260 * t * t;
				const tam = 8 + random(`s${i}`) * 12;
				return (
					<div
						key={i}
						style={{
							position: 'absolute',
							left: x,
							top: y,
							width: tam,
							height: tam * (random(`r${i}`) > 0.5 ? 1 : 0.45),
							borderRadius: random(`c${i}`) > 0.5 ? tam : 2,
							background: cores[i % cores.length],
							opacity: interpolate(t, [0, 0.1, 1.1, 1.6], [0, 1, 1, 0], clamp),
							transform: `rotate(${t * 540 * (random(`g${i}`) - 0.5)}deg)`,
						}}
					/>
				);
			})}
		</>
	);
};

/** O e-mail com o código chegando, no topo da tela (dados fictícios). */
const AvisoEmail: React.FC<{trecho: Trecho; pecas: PecaNoTempo[]}> = ({trecho, pecas}) => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();
	const e = trecho.email!;
	const ini = noTrecho(pecas, e.de);
	const fim = noTrecho(pecas, e.ate);
	if (ini === null || fim === null) return null;
	const entra = spring({frame: frame - s(ini), fps, config: {damping: 14}});
	const sai = spring({frame: frame - s(fim - 0.35), fps, config: {damping: 20}});
	const v = entra - sai;
	const cod = e.codigo.slice(0, 3) + ' ' + e.codigo.slice(3);
	const marca = interpolate(frame, [s(ini + 0.6), s(ini + 1.2)], [0, 1], clamp);
	return (
		<>
			{v > 0.001 && (
				<div
					style={{
						position: 'absolute',
						left: 20,
						right: 20,
						top: interpolate(v, [0, 1], [-240, 64]),
						borderRadius: 32,
						padding: '20px 24px',
						background: 'rgba(245,247,250,0.97)',
						color: '#0f172a',
						boxShadow: '0 18px 40px rgba(0,0,0,0.45)',
						display: 'flex',
						gap: 18,
						alignItems: 'center',
						transform: `scale(${0.9 + 0.1 * v})`,
					}}
				>
					<div
						style={{
							width: 72,
							height: 72,
							borderRadius: 20,
							background: `linear-gradient(180deg, ${COR.acaoClara}, ${COR.acao})`,
							display: 'flex',
							alignItems: 'center',
							justifyContent: 'center',
							flexShrink: 0,
						}}
					>
						<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
							<rect x="3" y="5" width="18" height="14" rx="2" />
							<path d="m3 7 9 6 9-6" />
						</svg>
					</div>
					<div style={{flex: 1}}>
						<div style={{fontSize: 21, color: '#64748b', display: 'flex', justifyContent: 'space-between'}}>
							<span>E-mail · SouPMRR</span>
							<span>agora</span>
						</div>
						<div style={{fontSize: 26, fontWeight: 700, marginTop: 2}}>Código de verificação</div>
						<div style={{fontSize: 26, marginTop: 4}}>
							Seu código é{' '}
							<Underline progress={marca} color={COR.ouro} strokeWidth={4} seed={7}>
								<b style={{color: COR.acao, letterSpacing: 2}}>{cod}</b>
							</Underline>
						</div>
					</div>
				</div>
			)}
			<Som arquivo="switch" aos={ini} volume={0.4} />
		</>
	);
};

// ── Legenda em estilo de rede social ───────────────────────────────────────

type Palavra = {p: string; i: number; f: number};

function blocosDeLegenda(palavras: Palavra[]): Palavra[][] {
	const saida: Palavra[][] = [];
	let atual: Palavra[] = [];
	let tam = 0;
	for (const w of palavras) {
		if (atual.length && (tam + w.p.length > 24 || atual.length >= 4)) {
			saida.push(atual);
			atual = [];
			tam = 0;
		}
		atual.push(w);
		tam += w.p.length + 1;
		if (/[.?!:,]$/.test(w.p) && atual.length >= 2) {
			saida.push(atual);
			atual = [];
			tam = 0;
		}
	}
	if (atual.length) saida.push(atual);
	return saida;
}

// Palavras que ganham cor própria na legenda.
const DESTAQUES = /^(SouPMRR|Primeiro|acesso|Esqueci|senha|CPF|e-mail|código|DTI|matrícula|Continuar|caminhos|dificuldades|Novidades|spam|SIGRH|verde|Pronto)/i;

const Legenda: React.FC<{palavras: Palavra[]; parte: number}> = ({palavras, parte}) => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();
	const t = frame / FPS;
	const blocos = blocosDeLegenda(palavras);
	let idx = blocos.findIndex((b) => t < b[b.length - 1].f + 0.08);
	if (idx === -1) idx = blocos.length - 1;
	const bloco = blocos[idx];
	if (t < bloco[0].i - 0.1) return null;
	const fimGeral = palavras[palavras.length - 1].f;
	if (t > fimGeral + 0.45) return null;
	const pop = spring({frame: frame - s(bloco[0].i - 0.1), fps, config: {damping: 12, stiffness: 220}});
	const top = parte === 1 || parte === 2 ? 1700 : parte === 3 ? 1420 : 1560;
	return (
		<div
			style={{
				position: 'absolute',
				left: 40,
				right: 40,
				top,
				display: 'flex',
				justifyContent: 'center',
				flexWrap: 'wrap',
				gap: '0 18px',
				transform: `scale(${0.8 + 0.2 * pop})`,
				opacity: Math.min(1, pop * 1.4),
			}}
		>
			{bloco.map((w, i) => {
				const falando = t >= w.i - 0.03 && t <= w.f + 0.08;
				const destaque = DESTAQUES.test(w.p.replace(/^["“]/, ''));
				return (
					<span
						key={i}
						style={{
							fontSize: 74,
							fontWeight: 700,
							lineHeight: 1.12,
							color: falando ? COR.ouro : destaque ? COR.azulClaro : '#fff',
							WebkitTextStroke: '10px rgba(3,11,24,0.92)',
							paintOrder: 'stroke fill',
							textShadow: '0 8px 24px rgba(0,0,0,0.6)',
							transform: `translateY(${falando ? -6 : 0}px) scale(${falando ? 1.06 : 1})`,
							display: 'inline-block',
						}}
					>
						{w.p}
					</span>
				);
			})}
		</div>
	);
};

// ── Abertura ────────────────────────────────────────────────────────────────

const aparece = (frame: number, aos: number, fps: number, damping = 14) =>
	spring({frame: frame - s(aos), fps, config: {damping}});

/** "Novidades no app SouPMRR!" */
const CenaNovidade: React.FC = () => {
	const f = useCurrentFrame();
	const {fps} = useVideoConfig();
	const icone = aparece(f, 0.15, fps, 11);
	const giro = interpolate(f, [0, s(4)], [0, 120]);
	const selo = aparece(f, 0.55, fps, 10);
	const letras = 'SouPM'.split('');
	return (
		<AbsoluteFill style={{alignItems: 'center'}}>
			<Circuito aos={0} />
			<Som arquivo="whoosh" aos={0.05} volume={0.5} />
			<Som arquivo="ding" aos={0.55} volume={0.35} />
			<div style={{position: 'relative', marginTop: 640, width: 420, height: 420, display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
				{/* anel de luz girando */}
				<div
					style={{
						position: 'absolute',
						inset: -40,
						borderRadius: '50%',
						background: `conic-gradient(from ${giro}deg, transparent 0deg, ${COR.azulClaro} 60deg, transparent 140deg, ${COR.ouro} 220deg, transparent 300deg)`,
						filter: 'blur(18px)',
						opacity: 0.75 * icone,
						transform: `scale(${icone})`,
					}}
				/>
				<div style={{position: 'relative', width: 380, height: 380, transform: `scale(${0.3 + 0.7 * icone}) rotate(${(1 - icone) * -25}deg)`}}>
					<Img src={staticFile('img/iconesoupm.png')} style={{width: 380, height: 380, borderRadius: 90, boxShadow: '0 30px 90px rgba(8,123,204,0.55)'}} />
					<Brilho aos={0.75} raio={90} />
				</div>
				<div
					style={{
						position: 'absolute',
						top: -60,
						right: -70,
						padding: '14px 30px',
						borderRadius: 40,
						background: `linear-gradient(180deg, ${COR.ouroClaro}, ${COR.ouro})`,
						color: '#1a1200',
						fontSize: 40,
						fontWeight: 700,
						letterSpacing: 3,
						transform: `scale(${selo}) rotate(${8 - 8 * selo + 6}deg)`,
						boxShadow: '0 12px 30px rgba(255,179,0,0.45)',
					}}
				>
					NOVIDADE
				</div>
			</div>
			<div style={{marginTop: 110, fontSize: 56, letterSpacing: 10, color: COR.azulClaro, opacity: aparece(f, 0.5, fps)}}>NOVIDADES NO APP</div>
			<div style={{display: 'flex', marginTop: 8}}>
				{letras.map((l, i) => {
					const k = aparece(f, 0.65 + i * 0.05, fps, 12);
					return (
						<span key={i} style={{fontSize: 150, fontWeight: 700, display: 'inline-block', transform: `translateY(${(1 - k) * 80}px)`, opacity: k}}>
							{l}
						</span>
					);
				})}
			</div>
		</AbsoluteFill>
	);
};

/** "Está com dificuldades para acessar o aplicativo?" */
const CenaPergunta: React.FC = () => {
	const f = useCurrentFrame();
	const {fps} = useVideoConfig();
	const cad = aparece(f, 0, fps, 13);
	const treme = f > s(0.5) && f < s(1.1) ? Math.sin(f * 2.2) * 14 * (1 - (f - s(0.5)) / s(0.6)) : 0;
	const linhas = [['Está', 'com'], ['dificuldades'], ['para', 'acessar'], ['o', 'app?']];
	let n = 0;
	return (
		<AbsoluteFill style={{alignItems: 'center'}}>
			<Som arquivo="whip" aos={0} volume={0.4} />
			{/* cadeado */}
			<div style={{marginTop: 560, transform: `scale(${cad}) translateX(${treme}px)`}}>
				<svg width="230" height="270" viewBox="0 0 230 270">
					<defs>
						<linearGradient id="cad" x1="0" y1="0" x2="0" y2="1">
							<stop offset="0" stopColor={COR.acaoClara} />
							<stop offset="1" stopColor={COR.acao} />
						</linearGradient>
					</defs>
					<path d="M55 120 V80 a60 60 0 0 1 120 0 V120" fill="none" stroke="#cfe8ff" strokeWidth="22" strokeLinecap="round" />
					<rect x="20" y="115" width="190" height="145" rx="34" fill="url(#cad)" />
					<circle cx="115" cy="175" r="20" fill="#e6f2ff" />
					<rect x="106" y="185" width="18" height="40" rx="9" fill="#e6f2ff" />
				</svg>
			</div>
			<div style={{marginTop: 70, display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
				{linhas.map((linha, li) => (
					<div key={li} style={{display: 'flex', gap: 26}}>
						{linha.map((palavra) => {
							const k = aparece(f, 0.25 + n++ * 0.18, fps, 12);
							const grande = palavra === 'dificuldades';
							const conteudo = (
								<span
									style={{
										fontSize: grande ? 130 : 96,
										fontWeight: 700,
										lineHeight: 1.08,
										color: grande ? COR.ouro : '#fff',
										display: 'inline-block',
										transform: `scale(${1.6 - 0.6 * k})`,
										opacity: k,
										filter: `blur(${(1 - k) * 10}px)`,
									}}
								>
									{palavra}
								</span>
							);
							return palavra === 'acessar' ? (
								<Underline key={palavra} progress={interpolate(f, [s(1.6), s(2.2)], [0, 1], clamp)} color={COR.azulClaro} strokeWidth={8} seed={4}>
									{conteudo}
								</Underline>
							) : (
								<React.Fragment key={palavra}>{conteudo}</React.Fragment>
							);
						})}
					</div>
				))}
			</div>
		</AbsoluteFill>
	);
};

/** "Existem dois caminhos." — um traço que se divide em dois. */
const CenaCaminhos: React.FC = () => {
	const f = useCurrentFrame();
	const {fps} = useVideoConfig();
	const tronco = interpolate(f, [0, s(0.45)], [0, 1], {...clamp, easing: SAIDA});
	const ramos = interpolate(f, [s(0.35), s(0.95)], [0, 1], {...clamp, easing: SAIDA});
	const titulo = aparece(f, 0, fps, 12);
	return (
		<AbsoluteFill style={{alignItems: 'center'}}>
			<Som arquivo="whoosh" aos={0.3} volume={0.4} />
			<div style={{marginTop: 400, fontSize: 64, color: COR.suave, opacity: titulo}}>Existem</div>
			<div style={{fontSize: 150, fontWeight: 700, lineHeight: 1, transform: `scale(${0.6 + 0.4 * titulo})`}}>
				<span style={{color: COR.ouro}}>2</span> caminhos
			</div>
			<svg width={1080} height={520} style={{marginTop: 30}}>
				<g fill="none" stroke={COR.azulClaro} strokeWidth={10} strokeLinecap="round" style={{filter: `drop-shadow(0 0 10px ${COR.azulClaro})`}}>
					<path d="M540 0 V170" pathLength={1} strokeDasharray={1} strokeDashoffset={1 - tronco} />
					<path d="M540 170 C540 300 270 260 270 470" pathLength={1} strokeDasharray={1} strokeDashoffset={1 - ramos} />
					<path d="M540 170 C540 300 810 260 810 470" pathLength={1} strokeDasharray={1} strokeDashoffset={1 - ramos} />
				</g>
				{tronco > 0.99 && <circle cx={540} cy={170} r={18} fill={COR.ouro} />}
			</svg>
			<div style={{position: 'absolute', top: 1200, left: 0, right: 0, display: 'flex', justifyContent: 'space-around', padding: '0 40px'}}>
				{[1, 2].map((n, i) => {
					const p = PARTES[n as 1 | 2];
					const k = aparece(f, 0.85 + i * 0.25, fps, 11);
					return (
						<div
							key={n}
							style={{
								position: 'relative',
								width: 440,
								padding: '34px 26px',
								borderRadius: 40,
								background: 'rgba(14,18,25,0.85)',
								border: `3px solid ${i ? 'rgba(66,165,245,0.55)' : 'rgba(255,179,0,0.55)'}`,
								display: 'flex',
								flexDirection: 'column',
								alignItems: 'center',
								textAlign: 'center',
								transform: `translateY(${(1 - k) * 160}px) scale(${0.7 + 0.3 * k})`,
								opacity: k,
								boxShadow: '0 20px 50px rgba(0,0,0,0.45)',
							}}
						>
							<div
								style={{
									width: 110,
									height: 110,
									borderRadius: 34,
									background: `linear-gradient(160deg, ${COR.acaoClara}, ${COR.acao})`,
									display: 'flex',
									alignItems: 'center',
									justifyContent: 'center',
									fontSize: 66,
									fontWeight: 700,
								}}
							>
								{p.numero}
							</div>
							<div style={{marginTop: 20, fontSize: 50, fontWeight: 700}}>{p.titulo}</div>
							<div style={{marginTop: 8, fontSize: 32, color: COR.suave, lineHeight: 1.25}}>{p.sub}</div>
							<Brilho aos={1.3 + i * 0.25} raio={40} />
						</div>
					);
				})}
			</div>
		</AbsoluteFill>
	);
};

// ── Cartão entre os caminhos ───────────────────────────────────────────────

const CartaoParte: React.FC<{parte: 1 | 2; dur: number}> = ({parte, dur}) => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();
	const p = PARTES[parte];
	const abre = interpolate(frame, [0, 12], [0, 150], {...clamp, easing: SAIDA});
	const fecha = interpolate(frame, [s(dur) - 9, s(dur)], [1, 0], clamp);
	const num = aparece(frame, 0.08, fps, 10);
	const tit = aparece(frame, 0.2, fps, 14);
	return (
		<AbsoluteFill style={{clipPath: `circle(${abre}% at 50% 45%)`, opacity: fecha}}>
			<Som arquivo="whoosh" aos={0} volume={0.5} />
			<AbsoluteFill style={{background: `radial-gradient(circle at 50% 45%, #0b3a6e, ${COR.fundo2} 70%)`}} />
			<AbsoluteFill style={{alignItems: 'center', justifyContent: 'center'}}>
				<div style={{fontSize: 40, letterSpacing: 12, color: COR.azulClaro, opacity: tit}}>CAMINHO</div>
				<div
					style={{
						position: 'relative',
						marginTop: 30,
						width: 260,
						height: 260,
						borderRadius: 76,
						background: `linear-gradient(160deg, ${COR.acaoClara}, ${COR.acao})`,
						display: 'flex',
						alignItems: 'center',
						justifyContent: 'center',
						fontSize: 170,
						fontWeight: 700,
						transform: `scale(${num}) rotate(${(1 - num) * 30}deg)`,
						boxShadow: '0 30px 80px rgba(8,123,204,0.5)',
					}}
				>
					{p.numero}
					<Brilho aos={0.45} raio={76} />
				</div>
				<div style={{marginTop: 50, overflow: 'hidden'}}>
					<div style={{fontSize: 96, fontWeight: 700, transform: `translateY(${(1 - tit) * 120}px)`}}>{p.titulo}</div>
				</div>
				<div style={{marginTop: 10, fontSize: 44, color: COR.suave, opacity: aparece(frame, 0.35, fps)}}>{p.sub}</div>
			</AbsoluteFill>
		</AbsoluteFill>
	);
};

// ── Encerramento ────────────────────────────────────────────────────────────

const Encerramento: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();
	const palavras = AUDIO['fim'].palavras;
	const tecnologias = palavras.filter((w) => /^Tecnologia/.test(w.p));
	const tLema = (tecnologias[1]?.i ?? 5) + ATRASO_VOZ - 0.1;
	const lema = 'Tecnologia ao seu dispor.';
	const letras = Math.floor(interpolate(frame, [s(tLema), s(tLema + 1.1)], [0, lema.length], clamp));
	const logo = aparece(frame, 0.35, fps, 12);
	return (
		<AbsoluteFill style={{alignItems: 'center'}}>
			<Circuito aos={0} opacidade={0.5} />
			<Som arquivo="whoosh" aos={0} volume={0.45} />
			<div style={{marginTop: 360, fontSize: 56, color: COR.ouro, fontWeight: 700, opacity: aparece(frame, 0, fps)}}>Ainda com problemas?</div>
			<div style={{position: 'relative', marginTop: 40, transform: `scale(${0.7 + 0.3 * logo})`, opacity: logo}}>
				<Img
					src={staticFile('img/logo_dti.jpeg')}
					style={{width: 760, mixBlendMode: 'lighten', WebkitMaskImage: 'radial-gradient(ellipse 70% 70% at 50% 50%, #000 60%, transparent 100%)'}}
				/>
			</div>
			<div style={{marginTop: 10, fontSize: 72, fontWeight: 700, opacity: aparece(frame, 0.9, fps)}}>
				Procure o <span style={{color: COR.ouro}}>DTI</span>
			</div>
			<div style={{marginTop: 14, fontSize: 40, color: COR.suave, opacity: aparece(frame, 1.2, fps)}}>Departamento de Tecnologia da Informação</div>
			<div style={{marginTop: 50, fontSize: 70, fontWeight: 700, fontStyle: 'italic', color: COR.azulClaro, minHeight: 90}}>
				{lema.slice(0, letras)}
				{letras > 0 && letras < lema.length && <span style={{color: COR.ouro}}>|</span>}
			</div>
			<Img src={staticFile('img/rodape_marcas.png')} style={{position: 'absolute', bottom: 60, width: 1000, opacity: aparece(frame, 0.6, fps)}} />
		</AbsoluteFill>
	);
};
