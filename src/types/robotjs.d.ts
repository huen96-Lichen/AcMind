declare module 'robotjs' {
  interface RobotJSLike {
    keyTap(key: string, modifier?: string | string[]): void;
  }

  const robotjs: RobotJSLike;
  export = robotjs;
}
