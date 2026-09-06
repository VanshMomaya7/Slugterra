import React from "react";
import { createRoot } from "react-dom/client";
import { Canvas, useFrame, useThree } from "@react-three/fiber";
import { Environment, Grid, Sparkles, Text } from "@react-three/drei";
import * as THREE from "three";
import { Model } from "./assets/Model";
import { Attribution } from "./ui/Attribution";
import "./styles.css";

type Shot = { id: number; t: number; transformed: boolean; origin: THREE.Vector3 };

const EMBEDS = [
  { label: "Infurnus reference", src: "https://sketchfab.com/models/ded8e71aaaf94bc4a5be48a81911ac3c/embed?autostart=1&ui_theme=dark" },
  { label: "Eli Shane reference", src: "https://sketchfab.com/models/f273b2800f644db4832093eb6336429f/embed?autostart=1&ui_theme=dark" },
];

function LiveModel({ title, src, credit }: { title: string; src: string; credit: string }) {
  return <article className="live-model">
    <div className="live-model-title"><span>{title}</span><small>{credit}</small></div>
    <iframe title={title} src={src} allow="autoplay; fullscreen; xr-spatial-tracking" allowFullScreen />
  </article>;
}

function Target({ damaged }: { damaged: boolean }) {
  return <group position={[0, 1.4, -10]}>
    <Model modelKey="target.dummy" {...(damaged ? { tint: "#6b2830" } : {})} />
    <mesh position={[0, 1.15, 0.12]}><ringGeometry args={[0.18, 0.27, 16]} /><meshBasicMaterial color={damaged ? "#5c6b70" : "#ffcf79"} /></mesh>
  </group>;
}

function PlayerAvatar({ positionRef }: { positionRef: React.RefObject<THREE.Vector3> }) {
  const group = React.useRef<THREE.Group>(null);
  // Follows the authoritative position ref rather than React state, so the
  // avatar never triggers a re-render at 60 Hz.
  useFrame(() => { if (group.current) group.current.position.copy(positionRef.current); });
  return <group ref={group}><Model modelKey="character.eli" /></group>;
}

function Arena({ charging, damaged, onPosition }: { charging: boolean; damaged: boolean; onPosition: (p: THREE.Vector3, yaw: number) => void }) {
  const player = React.useRef(new THREE.Vector3(0, 0, 4));
  const yaw = React.useRef(0);
  const keys = React.useRef<Record<string, boolean>>({});
  const { camera } = useThree();
  React.useEffect(() => { const down = (e: KeyboardEvent) => { keys.current[e.code] = true; }; const up = (e: KeyboardEvent) => { keys.current[e.code] = false; }; window.addEventListener("keydown", down); window.addEventListener("keyup", up); return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); }; }, []);
  useFrame((_, delta) => {
    const move = new THREE.Vector3((keys.current.KeyD ? 1 : 0) - (keys.current.KeyA ? 1 : 0), 0, (keys.current.KeyS ? 1 : 0) - (keys.current.KeyW ? 1 : 0));
    if (move.lengthSq()) { move.normalize().applyAxisAngle(new THREE.Vector3(0, 1, 0), yaw.current); player.current.addScaledVector(move, delta * 5); player.current.x = THREE.MathUtils.clamp(player.current.x, -18, 18); player.current.z = THREE.MathUtils.clamp(player.current.z, -18, 18); }
    const follow = new THREE.Vector3(player.current.x, player.current.y + 3.8, player.current.z + 7.2);
    camera.position.lerp(follow, 1 - Math.pow(0.0001, delta));
    camera.lookAt(player.current.x, player.current.y + 1.1, player.current.z - 5);
    onPosition(player.current, yaw.current);
  });
  return <>
    <ambientLight intensity={0.3} color="#78bcd1" /><directionalLight position={[4, 10, 4]} intensity={2} color="#ffd6a0" castShadow />
    <Environment preset="night" />
    <fog attach="fog" args={["#071016", 8, 48]} />
    <mesh rotation-x={-Math.PI / 2} receiveShadow><planeGeometry args={[80, 80]} /><meshStandardMaterial color="#18252b" roughness={0.9} /></mesh>
    <Grid args={[40, 40]} cellSize={2} cellThickness={0.35} cellColor="#23515d" sectionSize={10} sectionColor="#467f86" position={[0, 0.01, 0]} />
    {[-14, -7, 7, 14].map((x) => <mesh key={x} position={[x, 2, -10]} castShadow><cylinderGeometry args={[1.5, 2.4, 7, 8]} /><meshStandardMaterial color="#263b40" roughness={0.95} /></mesh>)}
    <Sparkles count={120} scale={[36, 8, 36]} size={2} speed={0.25} color="#61d7dd" />
    <PlayerAvatar positionRef={player} />
    <Target damaged={damaged} />
    <Text position={[0, 3.2, -12]} fontSize={0.65} color="#f2bc68" anchorX="center">QUIET LAWN // TRAINING CAVERN</Text>
    {charging && <Sparkles count={24} position={[0, 1.3, 3]} scale={1.4} color="#ff9d31" />}
  </>;
}

function App() {
  const [charging, setCharging] = React.useState(false); const [charge, setCharge] = React.useState(0); const [shot, setShot] = React.useState<Shot | null>(null); const [embed, setEmbed] = React.useState<number | null>(null); const [damaged, setDamaged] = React.useState(false); const playerPosition = React.useRef(new THREE.Vector3(0, 0, 4)); const started = React.useRef(0);
  React.useEffect(() => { const down = (e: KeyboardEvent) => { if (e.code === "Space" && !charging) { setCharging(true); started.current = performance.now(); } }; const up = (e: KeyboardEvent) => { if (e.code === "Space" && charging) { const c = Math.min(1, (performance.now() - started.current) / 900); setCharging(false); setCharge(c); const origin = playerPosition.current.clone(); setShot({ id: Date.now(), t: c, origin, transformed: c >= 0.676 }); if (c >= 0.676) { setDamaged(true); window.setTimeout(() => setDamaged(false), 1600); } window.setTimeout(() => setShot(null), 1600); } }; window.addEventListener("keydown", down); window.addEventListener("keyup", up); return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); }; }, [charging]);
  React.useEffect(() => { if (!charging) return; const timer = window.setInterval(() => setCharge(Math.min(1, (performance.now() - started.current) / 900)), 30); return () => window.clearInterval(timer); }, [charging]);
  return <main className="game-shell">
    <Canvas shadows camera={{ position: [0, 3.8, 11], fov: 58 }}><Arena charging={charging} damaged={damaged} onPosition={(p) => playerPosition.current.copy(p)} /></Canvas>
    <section className="live-models" aria-label="Live Sketchfab models used by this web build">
      <LiveModel title="Eli Shane // player model" credit="nayzen · Sketchfab" src="https://sketchfab.com/models/f273b2800f644db4832093eb6336429f/embed?autostart=1&ui_theme=dark" />
      <LiveModel title={shot?.transformed ? "Infurnus Velocimorph // live shot" : "Infurnus // equipped slug"} credit="DanSword · Sketchfab" src={`https://sketchfab.com/models/${shot?.transformed ? "4d7d2c1829f84d47b644009921482499" : "ded8e71aaaf94bc4a5be48a81911ac3c"}/embed?autostart=1&ui_theme=dark`} />
    </section>
    <header className="hud top"><div><span className="eyebrow">SLUGTERRA // WEB BUILD</span><h1>Quiet Lawn</h1></div><button className="model-button" onClick={() => setEmbed(embed === null ? 0 : null)}>Sketchfab models</button></header>
    <section className="hud bottom"><div className="instructions"><b>WASD</b> move <span>•</span> <b>Orbit</b> look <span>•</span> Hold <b>Space</b> to charge</div><div className="meter"><div className="meter-label"><span>INFURNUS // BURPY</span><strong>{Math.round(charge * 139)} MPH</strong></div><div className="track"><i style={{ width: `${charge * 100}%` }} /><em style={{ left: "67.6%" }} /></div><small>{shot ? (shot.transformed ? "VELOCIMORPH // HIT THE NOTCH" : "DUD // TOO SLOW") : "100 MPH transforms the slug"}</small></div></section>
    {embed !== null && <aside className="model-drawer"><div className="drawer-head"><div><span className="eyebrow">WEB-NATIVE REFERENCE</span><h2>{EMBEDS[embed].label}</h2></div><button onClick={() => setEmbed(null)} aria-label="Close model viewer">×</button></div><iframe title={EMBEDS[embed].label} src={EMBEDS[embed].src} allow="autoplay; fullscreen; xr-spatial-tracking" allowFullScreen /><div className="drawer-tabs">{EMBEDS.map((m, i) => <button className={i === embed ? "active" : ""} key={m.label} onClick={() => setEmbed(i)}>{m.label}</button>)}</div></aside>}
    <Attribution />
  </main>;
}

createRoot(document.getElementById("root")!).render(<React.StrictMode><App /></React.StrictMode>);
