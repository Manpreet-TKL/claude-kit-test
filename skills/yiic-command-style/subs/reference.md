# yiic command style — verbatim blocks

## File header (AGPL + author tag — copy from MirthCommand.php)

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

## getName / getHelp / actionIndex

```php
public function getName()
{
    return 'Mirth command to administrate the Mirth database';
}

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

public function actionIndex()
{
    echo $this->getHelp();
}
```

If the command takes options on the default action (like `DBReportsCommand`), `actionIndex` accepts the flags and falls back to `getHelp()` when required args are missing.

## Section banners (PHPDoc boxes, this exact form)

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

SCHEMA DESCRIPTIONS holds `public static $tables` / `$columns` / `$contentTypes`-style lookup arrays.

## Action PHPDoc (numbered workflow + @param)

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
public function actionDumpErrors($limit = 5000, $startDate = null, $endDate = null)
```

Called as `yiic mirth dumperrors --limit=5000 --startDate='2025-07-17'`.

## Non-default DB connection helper

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

## Output snippets

```php
echo "[" . date('Y-m-d H:i:s') . "] Analyzing table: " . $table['TABLE_NAME'] . "\n";

echo "Updating view: " . $view['TABLE_NAME'] . "...";
// … work …
echo "[DONE]\n";

echo str_pad("LOCAL_CHANNEL_ID", 20) . str_pad("NAME", 40) . "\n";
echo str_repeat('-', 60) . "\n";

$fh = fopen($filename, 'w');           // 'ab' to append
fputcsv($fh, array_keys($data[0]));
foreach ($data as $row) { fputcsv($fh, $row); }
fclose($fh);

echo "\033[0;31mError: \033[0m File already exists!\n\n";
exit(8);
```

## Interactive prompts

```php
echo "\nChoose channel (LOCAL_CHANNEL_ID): ";
$chanId = trim(fgets(STDIN));
if (!ctype_digit($chanId)) {
    echo "Invalid channel id - aborting.\n";
    return;
}
```

Validate immediately, print the abort reason, `return`.
