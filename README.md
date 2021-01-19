# waybackurls.pl
> Search for urls of (sub)domains using the web archive database

This tool is mainly based on [waybackurls](https://github.com/tomnomnom/waybackurls) by tomnomnom.

The biggest difference between this tool and the one on which it is based is the ability to filter results based on status code, Mime-Type and file extension, which allows obtaining more relevant results within the context of a specific target.

Furthermore, in the current version, the only source of query is the [wayback machine](https://web.archive.org/).

## Usage

```
waybackurls.pl [option(s)] <domain_1> <domain_2> ... <domain_n>

Options:

    -h, --help              Show this help message and exit
    -v, --version           Show program version and exit
    -s, --silent            Do not show status messages
    -j, --json              Output the urls in JSON format
    -e, --extensions        Comma-separated list of extensions to filter by
    -m, --mime-types        Comma-separated list of mime-types to filter by
    -c, --status-codes      Comma-separated list of status codes to filter by
    -i, --input-file        Read list of domains from file
    -d, --subdomains        Also search for subdomain urls (Default)
    -o, --output-file       Save output to a file, don't print to stdout
    -E, --exclude-exts      Comma-separated list of extensions to be ignored
    -M, --exclude-types     Comma-separated list of mime-types to be ignored
    -C, --exclude-codes     Comma-separated list of status codes to be ignored
    --no-subdomains         Don't search for subdomain urls
```

## Examples

```
user@host:~$ waybackurls.pl -o output.txt -E css,jpg,jpeg,js,pdf,doc,docx -C 404 targetsite.com
user@host:~$ waybackurls.pl --no-subdomains -e php,txt,bkp -c 200 --json -i targets.txt
user@host:~$ waybackurls.pl -o output.txt -C 404,403,500 -i - < targets.txt
user@host:~$ waybackurls.pl -M text/html,image/jpeg,text/css targetsite.com --json > output.txt

```

## Meta

[Lucas V. Araujo](https://github.com/LvMalware) – lucas.vieira.ar@disroot.org

Distributed under the GNU GPL license. See ``LICENSE`` for more information.

[GitHub Repository](https://github.com/LvMalware/waybackurls.pl)

## Contributing

1. Fork it (<https://github.com/LvMalware/waybackurls.pl/fork>)
2. Create your feature branch (`git checkout -b feature/fooBar`)
3. Commit your changes (`git commit -am 'Add some fooBar'`)
4. Push to the branch (`git push origin feature/fooBar`)
5. Create a new Pull Request

### Foud a bug? Want some new feature? Open an issue and I will take a look.
