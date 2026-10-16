# Painel de administração do SouPMRR — plano

Objetivo: gerenciar o SouPMRR por um painel (web e, para administradores, dentro
do próprio app), sem mexer em código nem publicar versão nova. O app desenha a
tela com o que a API devolve; a API lê a configuração do banco; o painel edita o
banco.

```
Painel web / área admin do app ──► API de administração ──► banco (soupm_*)
                                                               │
App do militar ◄── API do app (lê a configuração) ◄────────────┘
```

## 1. O que já está pronto (16/10/2026)

Módulo **Certidões**, primeiro a seguir o modelo:

| Onde | O quê |
|---|---|
| `public.soupm_config` | Uma linha por módulo (`chave`), com um JSON (`valor`). |
| `public.soupm_certidao_tipo` | Uma linha por tipo de certidão. |
| `sigrh/certidoes/certidao_config.php` | Lê as duas tabelas por cima dos padrões do código. Se a leitura falhar, valem os padrões e nada para. |
| `autoemissao.php` (painel) | Devolve tudo ao app: `servico`, `textos`, `declaracao`, `validade_dias` e, por tipo, `titulo`, `descricao`, `icone`, `etapas`, `situacao`. |
| `autoemissao.php` (emitir) | Recusa a emissão com o serviço ou o tipo desligados, mesmo que o app esteja aberto há horas. |
| App (`certidoes_page.dart`) | Usa os textos e ícones da API, mostra o aviso de serviço fora do ar e o selo "Temporariamente indisponível". Sem API (offline), usa os padrões locais. |

SQL: `api-soupmrr/sql/2026-10-16_soupm_config.sql`.

### `soupm_config`, chave `certidoes`

Campo ausente usa o padrão de `certidaoConfigPadrao()`.

```json
{
  "servico": {
    "ativo": true,
    "titulo": "Emissão de certidões indisponível",
    "mensagem": "A emissão de certidões está temporariamente suspensa. ..."
  },
  "textos": {
    "topo": "Emita suas certidões na hora. Elas ficam salvas aqui por {validade} dias ...",
    "escolha": "Escolha a certidão que você precisa.",
    "lista_vazia": "As certidões que você emitir ficam aqui por {validade} dias.",
    "botao": "Emitir nova certidão"
  },
  "validade_dias": 30,
  "limite_hora": 15,
  "declaracao": { "versao": 2, "texto": "Declaro que conferi ..." },
  "motivo_tipo_desativado": "Esta certidão está temporariamente indisponível. ...",
  "etapas_finais": ["Validando os dados da certidão", "Lavrando o documento", "..."]
}
```

- `{validade}` nos textos é trocado por `validade_dias`.
- **Declaração:** mudou o texto, aumente a `versao`. O app manda a versão que
  o militar leu, a API recusa versão antiga e a versão fica gravada em cada
  emissão e impressa no PDF.

### `soupm_certidao_tipo`

| Coluna | Uso |
|---|---|
| `tipo` | Chave fixa (`tempo_servico`, `vinculo_funcional`, `comportamento`, `ficha_funcional`). Tipo novo precisa de código: o PDF de cada um é escrito em `certidao_pdf.php`. |
| `titulo`, `descricao` | O que o militar lê na lista. Nulo = padrão. |
| `icone` | Chave: `tempo`, `escudo`, `medalha`, `ficha`, `documento`, `relogio`, `calendario`, `diploma`, `balanca`, `casa`, `saude`, `arma`. Chave nova exige incluir no mapa `_icones` do app. |
| `ordem` | Posição na lista. |
| `ativo`, `motivo_inativo` | Liga/desliga. Desligado, o app mostra o selo "Temporariamente indisponível" com o motivo e a API recusa a emissão. |
| `etapas` | JSON com as etapas do botão (as finais são somadas). |

### Operações de hoje (enquanto o painel não existe)

```sql
-- Tirar um tipo do ar
UPDATE public.soupm_certidao_tipo
   SET ativo = false, motivo_inativo = 'Em manutenção. Volta hoje às 18h.', atualizado_em = NOW()
 WHERE tipo = 'comportamento';

-- Voltar
UPDATE public.soupm_certidao_tipo SET ativo = true, motivo_inativo = NULL WHERE tipo = 'comportamento';

-- Serviço inteiro fora do ar
UPDATE public.soupm_config
   SET valor = jsonb_set(valor, '{servico,ativo}', 'false'), atualizado_em = NOW()
 WHERE chave = 'certidoes';
```

A mudança vale na próxima vez que o militar abrir a tela (ou puxar para
atualizar). Na emissão vale na hora.

## 2. Próximos passos

### 2.1 API de administração

- `sigrh/admin/` separado da API do app, com autenticação própria de
  administrador. Nada de token no app do militar.
- Perfis: quem pode ver, quem pode alterar, quem pode revogar certidão.
  Hoje `isSuperUser` existe só no app; o perfil precisa estar no banco e ser
  conferido na API.
- Toda alteração grava `atualizado_por`. Uma tabela
  `soupm_admin_log` (quem, quando, o quê, valor antes e depois) mantém o
  histórico.
- Usuário de banco próprio para o painel, com `UPDATE` nas tabelas `soupm_*`.
  O usuário da API do app continua só com `SELECT`.
- Endpoints previstos:
  - `GET/PUT config/{modulo}`
  - `GET/PUT certidoes/tipos/{tipo}`
  - `GET certidoes/emissoes`, com busca por matrícula, código ou data
  - `POST certidoes/{codigo}/revogar`, com motivo, para a DRH
  - `GET certidoes/verificacoes`, o log de consultas do QR

### 2.2 Painel web

- Telas: Módulos (liga/desliga), Certidões (tipos, textos, etapas, declaração),
  Emissões (lista, revogar), Verificações e Log de alterações.
- Pré-visualização do texto do app antes de salvar.

### 2.3 Administração dentro do app

- Aba visível só para administradores, com o perfil vindo da API.
- Começar pelo essencial: liga/desliga de serviço e de tipo, com motivo, e
  revogação de certidão pelo código.

### 2.4 Próximos módulos no mesmo modelo

Contracheque, Escalas, SVI, Mapa da Força, Avisos: cada um ganha uma chave em
`soupm_config` com `servico.ativo` e textos, e a tela do app passa a respeitar.
A regra é a mesma: o app só desenha, a API decide, o banco guarda.
