---
name: yiic-command-style
description: Apply Manpreet's house style when authoring or substantially editing OpenEyes Yii console commands (yiic) — classes extending CConsoleCommand, dropped into ace/commands/ (bind-mounted as /extra_commands on web/oe-manager). Covers file header, class skeleton, PHPDoc section banners (SCHEMA DESCRIPTIONS / HELPER FUNCTIONS / ACTIONS), getName/getHelp/actionIndex conventions, the heredoc help-text format, action parameter binding, DB access patterns (Yii::app()->db and the file-mounted-secrets pattern for non-default DBs), and the standard CSV / progress-log output style. Trigger whenever the user asks for a new yiic command, a new action on an existing command, or any non-trivial edit to a *Command.php file under commands/. Skip for unrelated PHP work.
---

# OpenEyes Yii console command style (`yiic`)

House style for `*Command.php` files that live in `commands/` (the `/extra_commands` bind-mount on `web` / `oe-manager`). Match the conventions in `MirthCommand.php` and `DBReportsCommand.php` — those are the canonical references. `DBACommand.php` is older and uses a less-polished banner style; don't copy from it.

## File layout (top → bottom)

```
1. <?php
2. OpenEyes AGPL header block (verbatim)
3. "Created by Manpreet Singh <manpreet.singh@toukanlabs.com>" tag comment
4. class <Name>Command extends CConsoleCommand
5.     public static $… arrays         (optional — for schema/lookup data)
6.     public function getName()
7.     public function getHelp()
8.     /** *** SCHEMA DESCRIPTIONS *** */  (optional banner section)
9.     /** *** HELPER FUNCTIONS *** */     (banner section)
10.    /** *** ACTIONS *** */              (banner section)
11. } // end class
```

## File header

Verbatim AGPL block followed by the author tag — copy from `MirthCommand.php`:

```php
<?php
/**
 * OpenEyes
 *
 * (C) OpenEyes Foundation, 2019
 * This file is part of OpenEyes.
 * OpenEyes is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 * OpenEyes is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.
 * You should have received a copy of the GNU Affero General Public License along with OpenEyes in a file titled COPYING. If not, see <http://www.gnu.org/licenses/>.
 *
 * @package OpenEyes
 * @link http://www.openeyes.org.uk
 * @author OpenEyes <info@openeyes.org.uk>
 * @copyright Copyright (c) 2019, OpenEyes Foundation
 * @license http://www.gnu.org/licenses/agpl-3.0.html The GNU Affero General Public License V3.0
 */

/**
 * Created by Manpreet Singh <manpreet.singh@toukanlabs.com>.
 */
class FooCommand extends CConsoleCommand
{
```

Filename is `<ClassName>.php` matching the class exactly; the command is then invoked as `yiic foo` (Yii lowercases the prefix automatically).

## `getName()` and `getHelp()`

`getName()` returns a single-sentence description (no trailing period in old files, fine either way):

```php
public function getName()
{
    return 'Mirth command to administrate the Mirth database';
}
```

`getHelp()` returns a heredoc — dashes for ruler lines, `USAGE:` block, action list, then optional `Examples:` block. Indent the heredoc body (Yii prints it verbatim):

```php
public function getHelp()
{
    return <<<EOH
        ----------------------------------------------------------------------------
        <Name> Command
        ----------------------------------------------------------------------------
        One-paragraph description of what this command does.

        USAGE:
            yiic <name> [action] [parameter]

        Following actions are available:

            index                             Show this help

            check                             Test database connectivity

            dosomething --flag=[value]        One-line description
                      Examples:
                               yiic <name> dosomething --flag=foo

        ----------------------------------------------------------------------------
    EOH;
}
```

`actionIndex()` is the default action — it prints help:

```php
public function actionIndex()
{
    echo $this->getHelp();
}
```

For commands that take options on the default action (like `DBReportsCommand`), `actionIndex` instead accepts the flags and falls back to `getHelp()` when required args are missing.

## Section banners

PHPDoc-style boxed banners separate the three sections — copy this exact form:

```php
/**
 * ****************************************************************************
 * ************************* SCHEMA DESCRIPTIONS ******************************
 * ****************************************************************************
 */

/**
 * ****************************************************************************
 * ************************* HELPER FUNCTIONS *********************************
 * ****************************************************************************
 */

/**
 * ****************************************************************************
 * ********************************* ACTIONS **********************************
 * ****************************************************************************
 */
```

Order: schema descriptions (if any) → helper functions → actions. `SCHEMA DESCRIPTIONS` holds `public static $tables`, `public static $columns`, `public static $contentTypes`-style lookup arrays used as cheatsheet/reference data.

## Actions

`action<PascalCase>()` — Yii invokes `actionFoo` for `yiic <cmd> foo`. Parameters become CLI flags:

```php
public function actionDumpErrors($limit = 5000, $startDate = null, $endDate = null)
{
    // called as: yiic mirth dumperrors --limit=5000 --startDate='2025-07-17' --endDate='2025-07-18'
}
```

- **Always give defaults** so the action works flag-free where it can. `null` defaults are used to mean "not supplied".
- **PHPDoc each non-trivial action** with a numbered workflow comment block and `@param` lines:

```php
/**
 * Dump processing error details to a timestamped CSV. Workflow:
 *   1. Show channel list and prompt user to pick one.
 *   2. Show connector list for that channel and prompt user to pick one (or all).
 *   3. Fetch up to $limit rows with optional date filters on RECEIVED_DATE.
 *   4. Write the result to ./errors_channel<id>_<Ymd_His>.csv
 *
 * @param int         $limit      Max rows to export (default 5000)
 * @param string|null $startDate  Optional 'YYYY-MM-DD' lower bound
 * @param string|null $endDate    Optional 'YYYY-MM-DD' upper bound
 */
```

- **In-action step comments use the boxed `/* ----- N. step ----- */` form** to mirror the workflow block.

## DB access

Default OE DB:

```php
$db = Yii::app()->db;
$rows  = $db->createCommand($sql)->queryAll();
$value = $db->createCommand($sql)->queryScalar();
$db->createCommand($sql)->execute();
```

Bind values rather than string-interpolating user-supplied data:

```php
$data = $db->createCommand($sql)->bindValues($params)->queryAll();
```

For a **non-default DB** (e.g. Mirth), expose a `static` connection helper at the top of the HELPER FUNCTIONS section. Read host/db/user from env, password from file-mounted Docker secret, then fall back to env, then `exit` with an error:

```php
public static function getMcDbConnection($host = 'db', $dbname = 'mirthdb', $username = 'root', $password = null)
{
    $envHost     = getenv('MIRTH_DB_HOST') ?: (getenv('DATABASE_HOST') ?: $host);
    $envDbname   = getenv('MIRTH_DB_NAME') ?: $dbname;
    $envUsername = getenv('MIRTH_DB_USER') ?: 'mirthconnect';
    $envPassword = file_exists("/run/secrets/MIRTH_DB_PASSWORD")
        ? rtrim(file_get_contents("/run/secrets/MIRTH_DB_PASSWORD"))
        : (getenv('MIRTH_DB_PASSWORD') ?: exit('Mirth DB password not found in secrets or environment variables'));

    $connection = new CDbConnection("mysql:host=$envHost;dbname=$envDbname", $envUsername, $envPassword);
    $connection->active = true;
    $connection->charset = 'utf8';
    $connection->emulatePrepare = false;

    return $connection;
}
```

Secrets always come from `/run/secrets/<NAME>` (Docker secrets mount), not from `getenv` alone.

## Output conventions

- **Timestamped progress lines** for long-running actions:
  ```php
  echo "[" . date('Y-m-d H:i:s') . "] Analyzing table: " . $table['TABLE_NAME'] . "\n";
  ```
- **Per-item `[DONE]` markers** for foreach loops:
  ```php
  echo "Updating view: " . $view['TABLE_NAME'] . "...";
  // … work …
  echo "[DONE]\n";
  ```
- **Tables to stdout** use `str_pad` for columns and `str_repeat('-', N)` for separators:
  ```php
  echo str_pad("LOCAL_CHANNEL_ID", 20) . str_pad("NAME", 40) . "\n";
  echo str_repeat('-', 60) . "\n";
  ```
- **CSV output**: column headers from `array_keys($result[0])` first, then rows via `fputcsv`. Open with `'w'` for new, `'ab'` to append:
  ```php
  $fh = fopen($filename, 'w');
  fputcsv($fh, array_keys($data[0]));
  foreach ($data as $row) { fputcsv($fh, $row); }
  fclose($fh);
  ```
- **CSV filenames** include a `date('Ymd_His')` timestamp and any disambiguator (channel id, table name, etc).
- **Errors and aborts**: red ANSI for "Error:" lines, then `exit(<nonzero>)`:
  ```php
  echo "\033[0;31mError: \033[0m File already exists!\n\n";
  exit(8);
  ```

## Interactive prompts

When an action needs operator input mid-run, `fgets(STDIN)` + `trim`:

```php
echo "\nChoose channel (LOCAL_CHANNEL_ID): ";
$chanId = trim(fgets(STDIN));
if (!ctype_digit($chanId)) {
    echo "Invalid channel id - aborting.\n";
    return;
}
```

Validate immediately, print the abort reason, `return`.

## Conventions cheatsheet

- **Class & file naming**: `<Name>Command.php` / `class <Name>Command extends CConsoleCommand`. CLI handle is the lowercased prefix (`MirthCommand` → `yiic mirth`).
- **Help format**: dashes-as-rulers, `USAGE:` heading in caps, action list with aligned descriptions, Examples block at the bottom.
- **`actionIndex` = help printer** unless the command takes top-level flags (then `actionIndex` validates them and falls back to `$this->getHelp()` on missing required args).
- **Schema/lookup data** belongs in `public static $arrays` under the SCHEMA DESCRIPTIONS banner, not buried inside actions.
- **Static helpers** for connection setup and shared utilities (`self::getMcDbConnection()`).
- **`@param` PHPDoc** for every action param; explain default behaviour when the param is omitted.
- **Bind, don't interpolate** SQL params from user input — `->bindValues([...])`.
- **`/run/secrets/<NAME>` is the source of truth for passwords**; env vars are a fallback.
- **No Composer / no namespaces** — these files load inside the legacy Yii 1.x autoload tree. Use bare class names (`CConsoleCommand`, `CDbConnection`, `Mailer`, `Yii::app()`).
- **Reports / output artifacts** dropped into the working directory by default (`__DIR__ . DIRECTORY_SEPARATOR . …`), or take an explicit `--filePath=` param.
- **Bind-mount context**: these files are dropped into a running container via the `commands:/extra_commands` mount — no image rebuild needed for changes. The skill applies to any `commands/` folder following this pattern, but the canonical home is `ace/commands/`.
