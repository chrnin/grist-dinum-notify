#!/usr/bin/env nu

def apikey [] {
  return ['Authorization', $'Bearer ($env.GRIST_APIKEY)']
}

def check_env [] {
    if  not (["GRIST_APIKEY", "GRIST_ORG", "GRIST_WORKSPACE", "GRIST_DOC", "GRIST_DOMAIN"]|all {|c| $c in ($env|columns)}) {
      error make {msg: "missing parameters in environment variables, see .env.example for more information"}
    }
}

def init_grist [] {
    check_env
    let apikey = ['Authorization', $'Bearer ($env.GRIST_APIKEY)']

    # organisations
    let organisations = http get --headers $apikey $"https://($env.GRIST_DOMAIN)/api/orgs"
    let org_id = try { $organisations | where name == $env.GRIST_ORG |get "id" | get 0 } catch { null }
    if $org_id == null {
      print $"FYI available organisations: ($organisations.name)"
      error make {msg: $"organisation not found: ($env.GRIST_ORG)"}
    }
    
    # workspace
    let workspaces = http get --headers $apikey $"https://($env.GRIST_DOMAIN)/api/orgs/($org_id)/workspaces"
    let workspace_id = try {$workspaces|where name == $env.GRIST_WORKSPACE|get id.0} catch { null }
    if $workspace_id == null {
      print $"FYI available workspaces are ($workspaces.name)"
      error make {msg: $"workspace not found: ($env.GRIST_WORKSPACE)"}
    }

    # document
    let doc_id = http get --headers (apikey) $"https://($env.GRIST_DOMAIN)/api/workspaces/($workspace_id)" |get docs.id.0
    let grist = {
       apikey: $apikey,
       org_id: $org_id,
       workspace_id: $workspace_id,
       doc_id: $doc_id,
    }
    return $grist
}

export-env {
    let grist_object = init_grist
    $env.GRIST = $grist_object
}

def grist_url [] { $"https://($env.GRIST_DOMAIN)/api" }

export def document_url [] {
    return $"(grist_url)/docs/($env.GRIST.doc_id)" 
}

export def table_url [table_name: string] {
    return $"(document_url)/tables/($table_name)"
}

export def record_url [table_name: string] {
    return $"(table_url $table_name)/records"
}

export def env [] {
    return $env.GRIST
}

export def tables [] {
    let apikey = ['Authorization', $'Bearer ($env.GRIST_APIKEY)']
    let tables = http get --headers $apikey $"https://($env.GRIST_DOMAIN)/api/docs/(env|get doc_id)/tables"
    return $tables.tables
}

export def records [table_name: string, --filter: any = {}] {
    let record_url = record_url $table_name
    let filter_url = $"?filter=($filter|to json|url encode)"
    let url = $"($record_url)($filter_url)"
    return (http get --headers $env.GRIST.apikey $url)
}

export def patch [table_name: string, records: list<record>] {
    let url = record_url $table_name
    let payload = {"records": $records}
    http patch --raw --content-type application/json --headers $env.GRIST.apikey $url $payload
}

export def table_exists [table_name: string] {
    if ($table_name |str capitalize) in (tables).id {
        return true 
    } else {
        return false
    }
}

export def create_table [table_name: string, table_schema: any] {
    if (table_exists $table_name) { 
        error make {msg: $"table ($table_name) already exists"}
    } 
	http post --content-type application/json --headers $env.GRIST.apikey $"(document_url)/tables" $table_schema
}

