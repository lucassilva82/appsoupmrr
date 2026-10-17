import {Composition} from 'remotion';
import {Tutorial} from './Tutorial';
import {FPS, montar} from './tempo';

export const Root: React.FC = () => (
	<Composition
		id="Tutorial"
		component={Tutorial}
		width={1080}
		height={1920}
		fps={FPS}
		durationInFrames={Math.ceil(montar().total * FPS)}
	/>
);
