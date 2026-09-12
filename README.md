# Nabu

O Nabu é um quadro visual infinito feito em Flutter/Dart. A primeira versão é
local-first: abre imediatamente com os dados salvos no aparelho e pode
sincronizar os elementos com um banco Turso.

## Versão 0.1.0

- quadro matematicamente navegável, sem `Container` gigante;
- pan com mouse ou toque e zoom com pinça/botões;
- criação de post-its, textos, retângulos e círculos;
- seleção, movimentação, edição com toque duplo e exclusão;
- desfazer e refazer;
- mini mapa;
- persistência local;
- sincronização opcional com Turso;
- exclusão remota reversível por `deleted_at`;
- testes e validação automática no GitHub Actions.

## Abrir o projeto

O repositório mantém apenas os arquivos independentes de plataforma. Depois de
clonar, gere os diretórios Android e Web e instale as dependências:

```bash
flutter create --platforms=android,web --project-name=nabu .
flutter pub get
flutter run
```

O workflow do GitHub executa essa preparação automaticamente.

## Criar o banco no Turso

Crie um banco novo no painel do Turso. Depois, no shell do Turso, aplique o
conteúdo de `database/migrations/001_initial.sql`. Todas as instruções usam
`CREATE TABLE IF NOT EXISTS` e `INSERT OR IGNORE`; nenhum dado existente é
apagado.

Para executar o aplicativo conectado ao banco:

```bash
flutter run \
  --dart-define=TURSO_DATABASE_URL=libsql://SEU-BANCO.turso.io \
  --dart-define=TURSO_AUTH_TOKEN=SEU_TOKEN
```

Sem essas duas opções, o Nabu funciona normalmente no modo local.

## Segurança

Nunca grave o token em um arquivo versionado, no `pubspec.yaml` ou no código.
Um segredo incluído com `--dart-define` também pode ser extraído de um APK ou
do JavaScript compilado. Esse modo é adequado apenas para uma primeira versão
pessoal. Antes de distribuir o aplicativo para outras pessoas, use tokens com
permissões mínimas ou uma API intermediária que aplique autenticação por
usuário.

## Organização

```text
lib/
  main.dart
  src/
    app.dart
    board/       # modelos, estado e interface do quadro
    data/        # persistência local e Turso
database/
  migrations/   # schema versionado e reversível
test/            # testes de modelo e operações do quadro
```

