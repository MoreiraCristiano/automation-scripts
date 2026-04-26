# Python Offline Libs Automation

Script único para download, instalação offline e remoção de pacotes Python em ambientes sem acesso à internet.

## Uso

```bash
./offline-libs.sh <comando> [opções]
```

## Comandos

### download
Baixa todos os pacotes especificados em um `requirements.txt` e gera um pacote compactado (`offline-packages.tar.gz`).

```bash
./offline-libs.sh download requirements.txt [opções]
```

**Opções:**
- `--platform`           Plataforma alvo (ex: manylinux2014_x86_64)
- `--python-version`     Versão do Python (ex: 312, 311)
- `--implementation`     Implementação (default: cp)
- `--abi`                ABI (default: auto)

**Exemplo:**
```bash
./offline-libs.sh download requirements.txt --platform manylinux2014_x86_64 --python-version 312
```

---

### install
Instala pacotes Python a partir de um pacote gerado pelo comando `download`.

```bash
./offline-libs.sh install <caminho/do/pacote.tar.gz>
```

- Recomenda-se executar dentro de um virtualenv.

**Exemplo:**
```bash
./offline-libs.sh install offline-packages.tar.gz
```

---

### uninstall
Remove todos os pacotes Python instalados no ambiente atual.

```bash
./offline-libs.sh uninstall
```

- Recomenda-se executar dentro de um virtualenv.
- O script solicita confirmação caso não esteja em um virtualenv.

---

## Exemplos

```bash
# 1. Baixar dependências (máquina com internet)
./offline-libs.sh download requirements.txt --python-version 312

# 2. Transferir offline-packages.tar.gz para ambiente airgapped

# 3. Instalar (ambiente airgapped)
./offline-libs.sh install offline-packages.tar.gz

# 4. Se precisar remover
./offline-libs.sh uninstall
```