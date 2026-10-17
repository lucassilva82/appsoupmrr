// Roteiro do vídeo: que trecho da gravação aparece em cada fala.
//
// Tempos em segundos da gravação (gravacoes/parte1.mp4 e parte2.mp4).
// Coordenadas e tamanhos em pontos do iPhone 18 Pro (402 × 874), as mesmas
// usadas para tocar no simulador.

export type Foco = {x: number; y: number; s: number};

export type Peca =
	// Toca a gravação de `de` até `ate`.
	| {de: number; ate: number; foco?: Foco; video?: Video; borrar?: boolean}
	// Mostra o quadro `congela` parado; `peso` divide o tempo que sobrar
	// entre as peças paradas do trecho.
	| {congela: number; peso?: number; min?: number; foco?: Foco; video?: Video; borrar?: boolean};

// Gravações em gravacoes/. "parte2-entrar" é o toque no botão Entrar, gravado
// à parte (na parte2 o login saiu pelo ✓ do teclado).
export type Video = 'parte1' | 'parte2' | 'parte2-entrar';

/** Toque no instante `t`: um círculo é desenhado em volta do elemento (centro x, y; tamanho w × h). */
export type Toque = {t: number; x: number; y: number; w: number; h: number; video?: Video};

export type Trecho = {
	audio: string; // id em narracao.json
	parte: 0 | 1 | 2 | 3; // 0 abertura, 3 encerramento
	cena?: 'novidade' | 'pergunta' | 'caminhos'; // cenas da abertura
	durMin?: number; // duração mínima (s), para a animação terminar
	video?: Video; // gravação padrão das peças
	passo?: number; // passo destacado na barra de progresso
	pecas?: Peca[];
	toques?: Toque[];
	email?: {codigo: string; de: number; ate: number}; // aviso do e-mail (tempo da gravação)
	sucesso?: number; // tempo da gravação em que aparece a tela de sucesso
};

const link = (x: number): Foco => ({x, y: 651, s: 1.45});

// Tamanhos dos elementos tocados (pontos).
const CAMPO = {w: 370, h: 54};
const BOTAO = {w: 370, h: 50};
const OPCAO = {w: 370, h: 56};
const OK = {w: 90, h: 46}; // tecla ✓ do teclado
const CAMPO_LOGIN = {w: 312, h: 52};

export const ROTEIRO: Trecho[] = [
	{audio: 'intro1', parte: 0, cena: 'novidade', durMin: 2.9},
	{audio: 'intro2', parte: 0, cena: 'pergunta', durMin: 3.3},
	{audio: 'intro3', parte: 0, cena: 'caminhos', durMin: 3.8},

	// ── 1 · Primeiro acesso ─────────────────────────────────────────────────
	{
		audio: '1a',
		parte: 1,
		video: 'parte1',
		passo: 0,
		pecas: [
			{congela: 0.4, peso: 1},
			{congela: 0.5, peso: 1, foco: link(280)},
			{de: 0.6, ate: 1.45, foco: link(280)},
			{de: 1.45, ate: 2.3},
		],
		toques: [{t: 1.22, x: 280, y: 651, w: 140, h: 34}],
	},
	{
		audio: '1b',
		parte: 1,
		video: 'parte1',
		passo: 1,
		pecas: [
			{de: 2.3, ate: 4.4},
			{congela: 4.4, peso: 1, min: 0.3},
			{de: 26.5, ate: 27.6},
		],
		toques: [
			{t: 2.62, x: 200, y: 349, ...CAMPO},
			{t: 26.82, x: 200, y: 420, ...BOTAO},
		],
	},
	{
		audio: '1c',
		parte: 1,
		video: 'parte1',
		passo: 2,
		pecas: [
			{congela: 27.8, peso: 1},
			{de: 28.4, ate: 31.3},
		],
		toques: [
			{t: 28.8, x: 200, y: 323, ...OPCAO},
			{t: 30.48, x: 200, y: 459, ...OPCAO},
		],
	},
	{
		audio: '1d',
		parte: 1,
		video: 'parte1',
		passo: 2,
		pecas: [
			{congela: 31.4, peso: 1},
			{de: 31.9, ate: 33.4},
			{de: 33.9, ate: 36.9},
		],
		toques: [
			{t: 32.22, x: 200, y: 524, w: 250, h: 30},
			{t: 34.18, x: 200, y: 391, ...OPCAO},
			{t: 35.96, x: 200, y: 459, ...OPCAO},
		],
	},
	{
		audio: '1e',
		parte: 1,
		video: 'parte1',
		passo: 3,
		pecas: [
			{congela: 37.2, peso: 1, min: 0.6},
			{de: 51.2, ate: 53.4},
			{de: 53.4, ate: 54.6},
			{congela: 55.9, peso: 2},
			{de: 74.4, ate: 76.6},
		],
		toques: [
			{t: 51.42, x: 200, y: 369, ...CAMPO},
			{t: 53.56, x: 200, y: 440, ...BOTAO},
			{t: 74.54, x: 200, y: 374, w: 370, h: 80},
		],
		email: {codigo: '482913', de: 54.4, ate: 74.6},
	},
	{
		audio: '1f',
		parte: 1,
		video: 'parte1',
		passo: 4,
		pecas: [
			{de: 78.1, ate: 81.9},
			{de: 94.3, ate: 97.9},
			{congela: 98.6, peso: 1, min: 0.2},
			{de: 104.9, ate: 106.6},
		],
		toques: [
			{t: 78.36, x: 200, y: 349, ...CAMPO},
			{t: 94.54, x: 349, y: 780, ...OK},
			{t: 95.84, x: 200, y: 589, ...CAMPO},
			{t: 105.2, x: 349, y: 780, ...OK},
		],
		sucesso: 105.6,
	},
	{
		audio: '1g',
		parte: 1,
		video: 'parte1',
		passo: 5,
		pecas: [
			{de: 106.6, ate: 107.6},
			{congela: 108.5, peso: 1, foco: {x: 200, y: 470, s: 1.3}},
		],
	},

	// ── 2 · Esqueci a senha ────────────────────────────────────────────────
	{
		audio: '2a',
		parte: 2,
		video: 'parte2',
		passo: 0,
		pecas: [
			{congela: 0.4, peso: 1},
			{congela: 0.5, peso: 1, foco: link(125)},
			{de: 0.8, ate: 1.75, foco: link(125)},
			{de: 1.75, ate: 2.8},
		],
		toques: [{t: 1.5, x: 125, y: 651, w: 140, h: 34}],
	},
	{
		audio: '2b',
		parte: 2,
		video: 'parte2',
		passo: 1,
		pecas: [
			{de: 2.8, ate: 5.6},
			{congela: 5.6, peso: 1, min: 0.2},
			{de: 12.6, ate: 13.9},
		],
		toques: [
			{t: 3.22, x: 200, y: 374, ...CAMPO},
			{t: 12.93, x: 200, y: 445, ...BOTAO},
		],
	},
	{
		audio: '2c',
		parte: 2,
		video: 'parte2',
		passo: 2,
		pecas: [
			{de: 13.9, ate: 19.5},
			{congela: 19.5, peso: 1, min: 0.2},
			{de: 33.0, ate: 35.3},
		],
		toques: [{t: 33.17, x: 200, y: 399, w: 370, h: 80}],
		email: {codigo: '731508', de: 14.4, ate: 33.0},
	},
	{
		audio: '2d',
		parte: 2,
		video: 'parte2',
		passo: 3,
		pecas: [
			{de: 36.4, ate: 39.9},
			{de: 52.6, ate: 56.0},
			{congela: 56.0, peso: 1, min: 0.2},
			{de: 66.7, ate: 68.6},
			{congela: 68.6, peso: 1, min: 0.3},
		],
		toques: [
			{t: 36.67, x: 200, y: 354, ...CAMPO},
			{t: 52.85, x: 349, y: 780, ...OK},
			{t: 54.02, x: 200, y: 594, ...CAMPO},
			{t: 66.91, x: 349, y: 780, ...OK},
		],
		sucesso: 67.3,
	},
	{
		audio: '2e',
		parte: 2,
		video: 'parte2',
		passo: 4,
		pecas: [
			{de: 70.0, ate: 71.2},
			{de: 82.6, ate: 84.0},
			{de: 95.7, ate: 97.5},
			{de: 1.0, ate: 2.25, video: 'parte2-entrar'},
			{de: 13.45, ate: 13.95, video: 'parte2-entrar', borrar: true},
			{congela: 13.95, peso: 1, min: 0.6, video: 'parte2-entrar', borrar: true},
		],
		toques: [
			{t: 70.25, x: 200, y: 408, ...BOTAO},
			{t: 82.76, x: 200, y: 410, ...CAMPO_LOGIN},
			{t: 95.92, x: 200, y: 477, ...CAMPO_LOGIN},
			{t: 2.0, x: 200, y: 581, w: 312, h: 56, video: 'parte2-entrar'},
		],
	},

	{audio: 'fim', parte: 3},
];

export const PARTES = {
	1: {
		numero: '1',
		titulo: 'Primeiro acesso',
		sub: 'Nunca entrou ou não lembra de nada',
		passos: ['Início', 'CPF', 'Perguntas', 'E-mail', 'Senha', 'Pronto'],
	},
	2: {
		numero: '2',
		titulo: 'Esqueci a senha',
		sub: 'Lembra o e-mail cadastrado',
		passos: ['Início', 'E-mail', 'Código', 'Senha', 'Entrar'],
	},
} as const;
