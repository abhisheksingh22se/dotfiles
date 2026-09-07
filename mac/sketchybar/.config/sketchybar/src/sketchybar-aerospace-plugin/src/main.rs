use std::env;
use std::fs;
use std::collections::HashMap;
use std::os::unix::net::UnixStream;
use std::io::prelude::*;
use serde::Deserialize;
use serde::de::DeserializeOwned;
use serde_json::{json, Value};
use std::ffi::{CStr,c_char};

static SOCKET_PATH: &'static str = concat!("/tmp/bobko.aerospace-", env!("USER"), ".sock");

// Must match SOCKET_PROTOCOL_VERSION in AeroSpace's Sources/Common/model/clientServer.swift
static SOCKET_PROTOCOL_VERSION: u32 = 1;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct AerospaceResponse {
    stderr: String,
    exit_code: i32,
    stdout: String,
    #[serde(default)]
    server_version_and_hash: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct AppFontEntry {
    icon_name: String,
    app_names: Vec<String>
}

#[derive(Debug, Deserialize)]
struct SketchybarDisplayFrame {
    x: f32,
}

#[derive(Debug ,Deserialize)]
struct SketchybarDisplay {
    #[serde(alias = "arrangement-id")]
    arrangement_id: i32,
    frame: SketchybarDisplayFrame,
}

#[derive(Debug, Deserialize)]
struct SketchybarBar {
    items: Vec<String>
}

#[derive(Debug, Deserialize)]
struct AerospaceWorkspace {
    #[serde(alias = "monitor-id")]
    monitor_id: i32,
    workspace: String,
    #[serde(alias = "workspace-is-focused")]
    focused: bool,
    #[serde(alias = "workspace-is-visible")]
    visible: bool,
}

#[derive(Debug, Deserialize)]
struct AerospaceWindow {
    #[serde(alias = "app-name")]
    app_name: String,
    #[serde(alias = "window-title")]
    window_title: String,
    #[serde(alias = "workspace")]
    workspace: String,
}


// Some apps report names carrying invisible bidi/format characters, e.g. WhatsApp reports
// "\u{200e}WhatsApp", which misses an exact map lookup. Fold those out and lowercase so both
// sides of the lookup agree.
fn normalize_app_name(name: &str) -> String {
    name.chars()
        .filter(|c| !matches!(c,
            '\u{200b}'..='\u{200f}' | '\u{202a}'..='\u{202e}' | '\u{2066}'..='\u{2069}' | '\u{feff}'))
        .collect::<String>()
        .trim()
        .to_lowercase()
}

fn insert_entries(map: &mut HashMap<String, String>, entries: Vec<AppFontEntry>) {
    for entry in entries {
        for name in entry.app_names {
            map.insert(normalize_app_name(&name), entry.icon_name.clone());
        }
    }
}

fn app_font_map(path: &str, overrides_path: &str) -> std::io::Result<HashMap<String, String>> {
    let app_font_str = fs::read_to_string(path)
        .expect("App font json should be available");

    let mut result: HashMap<String, String> = HashMap::new();
    insert_entries(&mut result, serde_json::from_str(&app_font_str)?);

    // User-owned overrides win over upstream, and survive font updates. Absent file is fine.
    if let Ok(local_str) = fs::read_to_string(overrides_path) {
        match serde_json::from_str::<Vec<AppFontEntry>>(&local_str) {
            Ok(local) => insert_entries(&mut result, local),
            Err(e) => eprintln!("ignoring malformed {overrides_path}: {e}"),
        }
    }

    Ok(result)
}


unsafe extern "C" {
    fn sketchybar_call(message: *const c_char, message_length: usize) -> *const c_char;
}

fn _sketchybar_call(message_bytes: &Vec<i8>) -> std::io::Result<&str> {
    let char_ptr = unsafe { sketchybar_call(message_bytes.as_ptr(), message_bytes.len()) };
    let c_str = unsafe { CStr::from_ptr(char_ptr) };
    Ok(c_str.to_str().unwrap())
}

fn sketchybar_query<T: DeserializeOwned>(message: &str) -> std::io::Result<T> {
    let message_fmt = format!("--query {message}");
    let message_bytes: Vec<i8> = message_fmt.bytes().map(|c| {
        if c == b' ' {
            0
        } else {
            c as i8
        }
    }).collect();
    let resp_value: T = serde_json::from_str(_sketchybar_call(&message_bytes)?)?;
    Ok(resp_value)
}

fn sketchybar_batched(messages: &Vec<Vec<i8>>) -> Result<(), &str> {
    let message_bytes: Vec<i8> = messages.join(&0);

    let char_ptr = unsafe { sketchybar_call(message_bytes.as_ptr(), message_bytes.len()) };
    let c_str = unsafe { CStr::from_ptr(char_ptr) };
    let ret_str = c_str.to_str().unwrap();
    if !ret_str.is_empty() {
        println!("{}", c_str.to_str().unwrap());
        return Err(ret_str);
    }
    Ok(())
}

fn sketchybar_set(entry_name: &str, params: Value) -> Result<Vec<i8>, &str> {
    let mut message_bytes: Vec<i8> = b"--set".map(|c| c as i8).to_vec();
    message_bytes.push(0);
    message_bytes.extend(entry_name.bytes().map(|c| c as i8));
    let mut objects = vec![(String::new(), params.as_object().unwrap())];
    loop {
        if objects.is_empty() {
            break;
        }
        let (prefix, obj) = objects.pop().unwrap();
        for (k, v) in obj {
            let prefixed_key = format!("{prefix}{k}");
            if v.is_object() {
                objects.push((format!("{prefixed_key}."), v.as_object().unwrap()));
            } else {
                message_bytes.push(0);
                message_bytes.extend(prefixed_key.bytes().map(|c| c as i8));
                message_bytes.push(b'=' as i8);
                let v_str = if let Some(val) = v.as_bool() {
                    if val { String::from("on") } else { String::from("off") }
                } else if let Some(val) = v.as_i64() {
                    val.to_string()
                } else if let Some(val) = v.as_f64() {
                    val.to_string()
                } else if let Some(val) = v.as_str() {
                    val.to_string()
                } else {
                    return Err("Failed to convert");
                };
                message_bytes.extend(v_str.bytes().map(|c| c as i8));
            }
        }
    }
    Ok(message_bytes)
}

fn sketchybar_add<'a,'b>(entry_type: &'a str, entry_name: &'a str, entry_position: &'a str) -> Result<Vec<i8>, &'b str> {
    let mut message_bytes: Vec<i8> = b"--add".map(|c| c as i8).to_vec();
    message_bytes.push(0);
    message_bytes.extend(entry_type.bytes().map(|c| c as i8));
    message_bytes.push(0);
    message_bytes.extend(entry_name.bytes().map(|c| c as i8));
    message_bytes.push(0);
    message_bytes.extend(entry_position.bytes().map(|c| c as i8));
    Ok(message_bytes)
}

fn sketchybar_move<'a,'b>(entry_name: &'a str, relation: &'a str, reference: &'a str) -> Result<Vec<i8>, &'b str> {
    let mut message_bytes: Vec<i8> = b"--move".map(|c| c as i8).to_vec();
    message_bytes.push(0);
    message_bytes.extend(entry_name.bytes().map(|c| c as i8));
    message_bytes.push(0);
    message_bytes.extend(relation.bytes().map(|c| c as i8));
    message_bytes.push(0);
    message_bytes.extend(reference.bytes().map(|c| c as i8));
    Ok(message_bytes)
}

fn sketchybar_add_bracket<'a,'b>(entry_name: &'a str, member: &'a str) -> Result<Vec<i8>, &'b str> {
    let mut message_bytes: Vec<i8> = b"--add".map(|c| c as i8).to_vec();
    message_bytes.push(0);
    message_bytes.extend(b"bracket".map(|c| c as i8));
    message_bytes.push(0);
    message_bytes.extend(entry_name.bytes().map(|c| c as i8));
    message_bytes.push(0);
    message_bytes.extend(member.bytes().map(|c| c as i8));
    Ok(message_bytes)
}

fn sketchybar_remove<'a,'b>(entry_name: &'a str) -> Result<Vec<i8>, &'b str> {
    let mut message_bytes: Vec<i8> = b"--remove".map(|c| c as i8).to_vec();
    message_bytes.push(0);
    message_bytes.extend(entry_name.bytes().map(|c| c as i8));
    Ok(message_bytes)
}

// Orders digit runs numerically and ahead of letters, so 2 < 10 < A.
fn workspace_sort_key(name: &str) -> (u8, u64, String) {
    let digits: String = name.chars().take_while(|c| c.is_ascii_digit()).collect();
    if digits.is_empty() {
        (1, 0, name.to_lowercase())
    } else {
        (0, digits.parse().unwrap_or(u64::MAX), name.to_lowercase())
    }
}

// Messages in both directions are a 4 byte little endian length prefix followed by JSON.
fn aerospace_write_u32(stream: &mut UnixStream, value: u32) -> std::io::Result<()> {
    stream.write_all(&value.to_le_bytes())
}

fn aerospace_read_u32(stream: &mut UnixStream) -> std::io::Result<u32> {
    let mut buf = [0u8; 4];
    stream.read_exact(&mut buf)?;
    Ok(u32::from_le_bytes(buf))
}

fn aerospace_write_msg(stream: &mut UnixStream, payload: &str) -> std::io::Result<()> {
    aerospace_write_u32(stream, payload.len() as u32)?;
    stream.write_all(payload.as_bytes())
}

fn aerospace_read_msg(stream: &mut UnixStream) -> std::io::Result<String> {
    let count = aerospace_read_u32(stream)? as usize;
    let mut buf = vec![0u8; count];
    stream.read_exact(&mut buf)?;
    String::from_utf8(buf).map_err(std::io::Error::other)
}

// The server expects the protocol version handshake before any request, and answers with the
// only version it supports.
fn aerospace_connect() -> std::io::Result<UnixStream> {
    let mut stream = UnixStream::connect(SOCKET_PATH)?;
    aerospace_write_u32(&mut stream, SOCKET_PROTOCOL_VERSION)?;
    let server_version = aerospace_read_u32(&mut stream)?;
    if server_version != SOCKET_PROTOCOL_VERSION {
        return Err(std::io::Error::other(format!(
            "Incompatible socket protocol: client {SOCKET_PROTOCOL_VERSION}, server {server_version}. Try restarting AeroSpace"
        )));
    }
    Ok(stream)
}

fn aerospace_command<T: DeserializeOwned>(stream: &mut UnixStream, command: &str) -> std::io::Result<T> {
    // windowId and workspace must always be present, explicitly null when unset, otherwise the
    // server complains about an incomplete request.
    let j = json!({
        "args": format!("{command} --json").split(" ").collect::<Vec<&str>>(),
        "stdin": "",
        "windowId": env::var("AEROSPACE_WINDOW_ID").ok().and_then(|v| v.parse::<u32>().ok()),
        "workspace": env::var("AEROSPACE_WORKSPACE").ok(),
    });
    aerospace_write_msg(stream, &j.to_string())?;
    let response = aerospace_read_msg(stream)?;
    let resp_data: AerospaceResponse = serde_json::from_str(&response)?;
    if resp_data.exit_code != 0 {
        return Err(std::io::Error::other(format!(
            "[{command}] failed with exit code {} (server {}): {}",
            resp_data.exit_code, resp_data.server_version_and_hash, resp_data.stderr
        )));
    }
    let resp_payload: T = serde_json::from_str(&resp_data.stdout)?;
    Ok(resp_payload)
}

fn main() -> std::io::Result<()> {

    // quickly switch background if we have it
    match (std::env::var("FOCUSED"), std::env::var("PREV_FOCUSED")) {
        (Ok(val), Ok(prev_val)) => {
            let mut env_msgs: Vec<Vec<i8>> = Vec::new();
            if let Ok(msg) = sketchybar_set(&format!("space.{val}"), json!(
                    {
                        "background": {"color": "0x44ffffff"},
                        "label": {"color": "0xffffffff"},
                        "icon": {"color": "0xffffffff"},
                    })) {
                env_msgs.push(msg);
            }
            if let Ok(msg) = sketchybar_set(&format!("space.{prev_val}"), json!(
                    {
                        "background": {"color": "0x00000000"},
                        "label": {"color": "0xffa0a0a0"},
                        "icon": {"color": "0xffa0a0a0"},
                    })) {
                env_msgs.push(msg);
            }
            if !env_msgs.is_empty() {
                let _ = sketchybar_batched(&env_msgs);
            }
            // Deliberately no early return: the recolor above lands immediately, then the
            // idempotent full sync below reconciles item existence, labels and order.
        },
        (_, _) => {}
    }

    let mut stream = aerospace_connect()?;

    let mut displays: Vec<SketchybarDisplay> = sketchybar_query("displays").unwrap();
    displays.sort_by(|a, b| a.frame.x.total_cmp(&b.frame.x));
    let bar_props: SketchybarBar = sketchybar_query("bar").unwrap();
    let mut items_exist: HashMap<String, bool> = bar_props.items.iter().filter(|n| n.contains("space.")).map(|n| (n.clone(), false)).collect();

    let home = env::var("HOME").map_err(std::io::Error::other)?;
    let font_dir = format!("{home}/.config/sketchybar/sketchybar-app-font/dist");
    let app_to_font = app_font_map(
        &format!("{font_dir}/icon_map.json"),
        &format!("{font_dir}/icon_map.local.json"),
    )?;

    let mut workspaces: Vec<AerospaceWorkspace> = aerospace_command(&mut stream, "list-workspaces --all --format %{monitor-id}%{workspace}%{workspace-is-visible}%{workspace-is-focused}")?;
    workspaces.sort_by(|a, b| {
        a.monitor_id.cmp(&b.monitor_id)
            .then_with(|| workspace_sort_key(&a.workspace).cmp(&workspace_sort_key(&b.workspace)))
    });
    let windows: Vec<AerospaceWindow> = aerospace_command(&mut stream, "list-windows --all --format %{app-name}%{window-title}%{workspace}")?;

    let mut messages: Vec<Vec<i8>> = Vec::new();
    let mut ordered_names: Vec<String> = Vec::new();
    let mut membership_changed = false;
    for workspace in workspaces {
        let space = workspace.workspace;
        let space_name = format!("space.{space}");
        ordered_names.push(space_name.clone());

        let mut cur_apps: Vec<String> = windows.iter().enumerate().filter(|(_, w)| {
            w.window_title != "" && w.workspace == space
        }).map(|(_, w)| {
            if let Some(n) = app_to_font.get(&normalize_app_name(&w.app_name)) {
                n.clone()
            } else {
                String::from(":default:")
            }
        }).collect();
        cur_apps.sort();
        cur_apps.dedup();
        let label = String::from(" ") + &cur_apps.join(" ");

        // A monitor hotplug can briefly leave aerospace and sketchybar disagreeing about the
        // display list; fall back rather than panicking mid-batch.
        let display_id = displays
            .get((workspace.monitor_id - 1).max(0) as usize)
            .or(displays.first())
            .map(|d| d.arrangement_id)
            .unwrap_or(1);

        let rpad = if label.len() < 2 { 0 } else { 10 };
        let bg_color= if workspace.focused { "0x44ffffff" } else { "0x00000000" };
        let color = if workspace.visible { "0xffffffff" } else { "0xffc0c0c0" };
        let params = json!({
            "background": {
                "color": bg_color,
                "corner_radius": 5,
                "height": 20,
            },
            "label": {
                "string": label,
                "color": color,
                "padding_right": rpad,
                "padding_left": 6,
                "y_offset": -1,
                "drawing": "on",
                "font": "sketchybar-app-font:Mono:12.0",
            },
            "icon": {
                "string": space,
                "font": {
                    "size": 12.0
                },
                "padding_left": 8,
                "padding_right": 0,
                "color": color,
            },
            "click_script": format!("aerospace workspace {space}"),
            "display": display_id,
        });

        if let Some(e) = items_exist.get_mut(&space_name) {
            *e = true;
            if let Ok(m) = sketchybar_set(&space_name, params) {
                messages.push(m);
            }
        } else {
            membership_changed = true;
            if let Ok(m) = sketchybar_add("item", &space_name, "left") {
                messages.push(m);
            }
            if let Ok(m) = sketchybar_set(&space_name, params) {
                messages.push(m);
            }
        }
    }

    for (n, e) in items_exist {
        if !e {
            membership_changed = true;
            if let Ok(m) = sketchybar_remove(&n) {
                messages.push(m);
            }
        }
    }

    // --add only appends to a region and --set never moves anything, so an item's slot would
    // otherwise be frozen at whatever the add order happened to be. Restating the whole chain
    // every run makes position independent of add/remove history.
    let mut previous = String::from("aerospace");
    for name in &ordered_names {
        if let Ok(m) = sketchybar_move(name, "after", &previous) {
            messages.push(m);
        }
        previous = name.clone();
    }

    // Brackets resolve members when created, so the capsule has to be rebuilt whenever the
    // workspace set changes. Steady state stays a pure --set batch.
    if membership_changed {
        if let Ok(m) = sketchybar_remove("spaces_capsule") {
            messages.push(m);
        }
        if let Ok(m) = sketchybar_add_bracket("spaces_capsule", "/space\\..*/") {
            messages.push(m);
        }
        if let Ok(m) = sketchybar_set("spaces_capsule", json!({
            "background": {
                "color": "0x25000000",
                "corner_radius": 10,
                "border_width": 1,
                "border_color": "0x20ffffff",
                "height": 26,
            },
        })) {
            messages.push(m);
        }
    }
    // let messages_fmt = messages.iter().map(|m| String::from_utf8(
    //         m.iter().map(
    //             |c| if *c == 0 { '|' as u8 } else { *c as u8 }
    //             ).collect::<Vec<u8>>()).unwrap()).collect::<Vec<String>>().join("#");
    // println!("{}", messages_fmt);
    let _ = sketchybar_batched(&messages);
    Ok(())
}
