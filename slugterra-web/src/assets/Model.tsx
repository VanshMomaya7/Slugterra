/**
 * Renders a manifest entry: the real Sketchfab mesh when it is on disk, the
 * primitive fallback when it is not.
 *
 * The `.glb` files are fetched with `npm run assets` and are not committed, so
 * a clean checkout has none of them. This component is what makes that a
 * non-event — a missing or broken model degrades to a coloured primitive
 * instead of throwing inside a Suspense boundary and blanking the canvas.
 */

import { Suspense, useMemo } from 'react';
import { useGLTF } from '@react-three/drei';
import type { ObjectMap } from '@react-three/fiber';
import type { GLTF } from 'three-stdlib';
import * as THREE from 'three';
import { getModel, type ModelEntry, type ModelKey, type PrimitiveRef } from './manifest';

export interface ModelProps {
  modelKey: ModelKey;
  position?: readonly [number, number, number];
  rotation?: readonly [number, number, number];
  /** Multiplies the manifest's own scale correction. */
  scale?: number;
  castShadow?: boolean;
  receiveShadow?: boolean;
  /** Overrides the fallback tint — used for the Velocimorph glow. */
  tint?: string;
}

/** The greybox stand-in. Always renderable, never fetches anything. */
export function Primitive({
  primitive,
  castShadow = true,
  tint,
}: {
  primitive: PrimitiveRef;
  castShadow?: boolean;
  tint?: string;
}) {
  const color = tint ?? primitive.tint;
  return (
    <mesh castShadow={castShadow}>
      {primitive.shape === 'sphere' && <sphereGeometry args={[primitive.size, 16, 12]} />}
      {primitive.shape === 'capsule' && (
        <capsuleGeometry args={[primitive.size, primitive.size * 2.6, 8, 16]} />
      )}
      {primitive.shape === 'box' && (
        <boxGeometry args={[primitive.size * 2, primitive.size * 2, primitive.size * 2]} />
      )}
      <meshStandardMaterial color={color} roughness={0.55} />
    </mesh>
  );
}

/**
 * Loads the mesh. Suspends while fetching, so it always sits behind a
 * `<Suspense>` with the primitive as the fallback.
 */
function LoadedModel({ entry, tint }: { entry: ModelEntry; tint?: string }) {
  const gltf = useGLTF(entry.url) as unknown as GLTF & ObjectMap;

  // Clone so the same cached GLTF can appear more than once — Burpy is both the
  // dormant slug and the Velocimorph, and a shared scene graph cannot be in two
  // places at once.
  const scene = useMemo(() => {
    const copy = gltf.scene.clone(true);
    if (tint !== undefined) {
      copy.traverse((child) => {
        const mesh = child as THREE.Mesh;
        if (!mesh.isMesh) return;
        const source = mesh.material as THREE.Material | THREE.Material[];
        const recolor = (material: THREE.Material): THREE.Material => {
          const cloned = material.clone();
          if ('color' in cloned) {
            (cloned as THREE.MeshStandardMaterial).color = new THREE.Color(tint);
          }
          if ('emissive' in cloned) {
            (cloned as THREE.MeshStandardMaterial).emissive = new THREE.Color(tint);
            (cloned as THREE.MeshStandardMaterial).emissiveIntensity = 0.35;
          }
          return cloned;
        };
        mesh.material = Array.isArray(source) ? source.map(recolor) : recolor(source);
      });
    }
    return copy;
  }, [gltf.scene, tint]);

  return <primitive object={scene} />;
}

/**
 * An error boundary is required rather than optional here: `useGLTF` throws on
 * a 404, and an uncaught throw inside Suspense unmounts the whole subtree. This
 * catches it and shows the primitive, which is exactly the clean-checkout case.
 */
import { Component, type ReactNode } from 'react';

const reportedMissing = new Set<string>();

class ModelErrorBoundary extends Component<
  { fallback: ReactNode; children: ReactNode; url: string },
  { failed: boolean }
> {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  componentDidCatch() {
    // Once per URL, not once per mount: a missing asset is the expected state
    // on a clean checkout, and the same model can appear many times in a scene.
    if (reportedMissing.has(this.props.url)) return;
    reportedMissing.add(this.props.url);
    console.info(
      `[assets] ${this.props.url} unavailable - using the greybox fallback. ` +
        'Run `npm run assets` with a SKETCHFAB_TOKEN to fetch the real models.',
    );
  }

  render() {
    return this.state.failed ? this.props.fallback : this.props.children;
  }
}

export function Model({
  modelKey,
  position,
  rotation,
  scale = 1,
  castShadow = true,
  tint,
}: ModelProps) {
  const entry = getModel(modelKey);
  const fallback = (
    <Primitive primitive={entry.fallback} castShadow={castShadow} tint={tint} />
  );

  const transformRotation = entry.transform.rotation ?? [0, 0, 0];
  const transformPosition = entry.transform.position ?? [0, 0, 0];

  return (
    <group
      position={position ?? [0, 0, 0]}
      rotation={rotation ?? [0, 0, 0]}
      scale={scale}
    >
      <group
        position={transformPosition as [number, number, number]}
        rotation={transformRotation as [number, number, number]}
        scale={entry.transform.scale}
      >
        <ModelErrorBoundary url={entry.url} fallback={fallback}>
          <Suspense fallback={fallback}>
            <LoadedModel entry={entry} {...(tint !== undefined ? { tint } : {})} />
          </Suspense>
        </ModelErrorBoundary>
      </group>
    </group>
  );
}

/**
 * Warms the GLTF cache. Safe to call when the files are absent — drei swallows
 * the rejection and `Model` falls back.
 */
export function preloadModels(urls: string[]): void {
  for (const url of urls) {
    try {
      useGLTF.preload(url);
    } catch {
      // A missing asset is expected on a clean checkout.
    }
  }
}
