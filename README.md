# STAMPBIT

Ecossistema de colecionismo digital com estética Industrial CNC e Luxo Digital Cyberpunk.

## Estrutura

```
/projeto-stampbit
├── public/            # Assets estaticos (imagens, icones)
├── src/
│   ├── database.js    # Conexao Supabase
│   ├── auth.js        # Logica de autenticacao
│   └── engine.js      # Logica da forja de selos
├── .env               # Variaveis de ambiente (nao subir ao git)
├── index.html         # Interface principal v2.4.1
├── style.css          # Estetica Industrial CNC
├── schema.sql         # Schema do banco Supabase
└── README.md
```

## Setup

1. Clone o repositorio
2. Configure o arquivo `.env` com as credenciais do Supabase
3. Execute o schema `schema.sql` no SQL Editor do Supabase
4. Abra `index.html` no navegador ou sirva com um servidor local

## Tecnologias

- HTML5 Semantico
- CSS3 Moderno (Grid, Glassmorphism, Clip-path)
- Vanilla JavaScript (ES Modules)
- Supabase (Auth + Database)

## Schema do Banco

- `stamps`: Catalogo de selos (id, name, rarity, image_url, serial_prefix, total_supply)
- `inventory`: Relacao one-to-many usuarios-selos com hash unico de validacao

## Seguranca

- RLS (Row Level Security) ativo no Supabase
- Hashes SHA-256 gerados via trigger no banco
- Variaveis sensiveis isoladas no `.env`

---

DESIGNED COMMAND SOLUCOES TECNOLOGIA // PROTOCOLO ALLBIONICS // 2026
