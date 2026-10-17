import audio from './audio.json';
import {Foco, Peca, ROTEIRO, Trecho} from './roteiro';

export const FPS = 30;
export const ATRASO_VOZ = 0.3; // respiro antes da fala
export const FOLGA = 0.3; // respiro depois da fala
export const CARTAO = 1.1; // cartão de título entre as partes
export const FIM_EXTRA = 1.8; // segura o encerramento depois da fala

type Audio = {arquivo: string; duracao: number; palavras: {p: string; i: number; f: number}[]};
export const AUDIO = audio as Record<string, Audio>;

export type PecaNoTempo = Peca & {ini: number; fim: number};

export type Bloco =
	| {tipo: 'cartao'; parte: 1 | 2; ini: number; dur: number}
	| {tipo: 'trecho'; trecho: Trecho; ini: number; dur: number; pecas: PecaNoTempo[]};

const ehParada = (p: Peca): p is Extract<Peca, {congela: number}> => 'congela' in p;

function distribuir(trecho: Trecho, durFala: number) {
	const pecas = trecho.pecas ?? [];
	const fixo = pecas.reduce((s, p) => s + (ehParada(p) ? 0 : p.ate - p.de), 0);
	const minimos = pecas.reduce((s, p) => s + (ehParada(p) ? p.min ?? 0 : 0), 0);
	const dur = Math.max(durFala, fixo + minimos);
	const sobra = dur - fixo - minimos;
	const pesos = pecas.reduce((s, p) => s + (ehParada(p) ? p.peso ?? 1 : 0), 0);
	let t = 0;
	const noTempo: PecaNoTempo[] = pecas.map((p) => {
		const d = ehParada(p) ? (p.min ?? 0) + (pesos ? (sobra * (p.peso ?? 1)) / pesos : 0) : p.ate - p.de;
		const r = {...p, ini: t, fim: t + d};
		t += d;
		return r;
	});
	return {dur, pecas: noTempo};
}

export function montar(): {blocos: Bloco[]; total: number} {
	const blocos: Bloco[] = [];
	let t = 0;
	let parteAnterior = 0;
	for (const trecho of ROTEIRO) {
		if ((trecho.parte === 1 || trecho.parte === 2) && trecho.parte !== parteAnterior) {
			blocos.push({tipo: 'cartao', parte: trecho.parte, ini: t, dur: CARTAO});
			t += CARTAO;
		}
		parteAnterior = trecho.parte;
		const fala = AUDIO[trecho.audio].duracao + ATRASO_VOZ + FOLGA + (trecho.parte === 3 ? FIM_EXTRA : 0);
		const {dur, pecas} = distribuir(trecho, Math.max(fala, trecho.durMin ?? 0));
		blocos.push({tipo: 'trecho', trecho, ini: t, dur, pecas});
		t += dur;
	}
	return {blocos, total: t};
}

/** Instante (no trecho) em que a gravação passa pelo tempo `tv`. */
export function noTrecho(pecas: PecaNoTempo[], tv: number, video?: string): number | null {
	for (const p of pecas) {
		if ((p.video ?? undefined) !== video) continue;
		if (!ehParada(p) && tv >= p.de && tv <= p.ate) return p.ini + (tv - p.de);
	}
	return null;
}

/** Tempo da gravação mostrado no instante `t` do trecho. */
export function naGravacao(pecas: PecaNoTempo[], t: number): number {
	const p = pecas.find((x) => t >= x.ini && t < x.fim) ?? pecas[pecas.length - 1];
	return ehParada(p) ? p.congela : p.de + (t - p.ini);
}

const SEM_ZOOM: Foco = {x: 201, y: 437, s: 1};
const suave = (x: number) => (x < 0 ? 0 : x > 1 ? 1 : x * x * (3 - 2 * x));

/** Zoom no instante `t`: passa de um foco ao outro em 0,5 s. */
export function focoEm(pecas: PecaNoTempo[], t: number): Foco {
	const achou = pecas.findIndex((x) => t >= x.ini && t < x.fim);
	const idx = achou === -1 ? pecas.length - 1 : achou;
	const atual = pecas[idx]?.foco ?? SEM_ZOOM;
	const antes = idx > 0 ? pecas[idx - 1].foco ?? SEM_ZOOM : SEM_ZOOM;
	const k = suave((t - pecas[idx].ini) / 0.5);
	return {
		x: antes.x + (atual.x - antes.x) * k,
		y: antes.y + (atual.y - antes.y) * k,
		s: antes.s + (atual.s - antes.s) * k,
	};
}
