# Nabu

O Nabu é um quadro visual infinito feito em Flutter/Dart. A primeira versão é
local-first: abre imediatamente com os dados salvos no aparelho e pode
sincronizar os elementos com um banco Turso.

## Versão 0.3.0

- quadro matematicamente navegável, sem `Container` gigante;
- pan com mouse ou toque e zoom com pinça/botões;
- criação de post-its, textos, retângulos e círculos;
- seleção, movimentação, edição com toque duplo e exclusão;
- ancoragem individual para impedir movimentos acidentais;
- importação de imagens com alternância entre retrato e paisagem;
- exibição completa da imagem, sem cortar capas e documentos;
- desfazer e refazer;
- mini mapa;
- persistência local;
- configuração, teste e sincronização opcional com Turso dentro do app;
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

## Conectar ao Turso

Toque no ícone de nuvem, informe a URL e o token do banco e use **Testar
conexão**. O Nabu cria as tabelas ausentes automaticamente com instruções
`CREATE TABLE IF NOT EXISTS`; nenhum dado existente é apagado. Depois, toque
em **Salvar e conectar**. O token fica no armazenamento seguro do aparelho.

Durante o desenvolvimento, também é possível fornecer as credenciais ao
executar o aplicativo:

```bash
flutter run \
  --dart-define=TURSO_DATABASE_URL=libsql://SEU-BANCO.turso.io \
  --dart-define=TURSO_AUTH_TOKEN=SEU_TOKEN
```

Sem essas duas opções, o Nabu funciona normalmente no modo local.

## Solução de problemas

Se o teste do Turso falhar, confirme que a URL começa com `libsql://` e
gere um token válido no painel do banco. A build Android de produção inclui
explicitamente a permissão `android.permission.INTERNET`.

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
